import CoreML
import Foundation
public protocol ModelProtocol {
    func prediction(from input: MLFeatureProvider) throws -> MLFeatureProvider
}
extension MLModel: ModelProtocol {}
public class KataGoInference {
    private let modelLoader = ModelLoader()
    private var aiModel: (any ModelProtocol)?
    private var humanSLModel: (any ModelProtocol)?

    public init() {}

    private func isHumanSLProfile(_ profile: String) -> Bool {
        guard profile.range(of: #"^(\d+)([kd])$"#, options: .regularExpression) != nil else {
            return false
        }
        guard let suffix = profile.last, (suffix == "d" || suffix == "k") else {
            return false
        }
        let numberPart = String(profile.dropLast())
        guard let number = Int(numberPart) else {
            return false
        }
        if suffix == "d" {
            return number >= 1 && number <= 9
        } else {
            return number >= 1 && number <= 20
        }
    }

    private func getModel(for profile: String) throws -> any ModelProtocol {
        if profile == "AI" {
            guard let model = aiModel else {
                throw KataGoError.modelNotFound("AI model not loaded. Call loadModel(for: \"AI\") first.")
            }
            return model
        } else if isHumanSLProfile(profile) {
            guard let model = humanSLModel else {
                throw KataGoError.modelNotFound("Human SL model not loaded. Call loadModel(for: \"20k\") or similar first.")
            }
            return model
        } else {
            guard let model = aiModel else {
                throw KataGoError.modelNotFound("AI model not loaded. Call loadModel(for: \"AI\") first.")
            }
            return model
        }
    }

    internal func setModel(_ model: any ModelProtocol, for profile: String) {
        if profile == "AI" {
            aiModel = model
        } else if isHumanSLProfile(profile) {
            humanSLModel = model
        } else {
            aiModel = model
        }
    }

    public func loadModel(for profile: String) throws {
        if profile == "AI" {
            if aiModel == nil {
                let modelName = "KataGoModel19x19fp16-s12192M"
                aiModel = try modelLoader.loadModel(name: modelName)
            }
        } else if isHumanSLProfile(profile) {
            if humanSLModel == nil {
                let modelName = "KataGoModel19x19fp16m1"
                humanSLModel = try modelLoader.loadModel(name: modelName)
            }
        } else {
            throw KataGoError.unsupportedProfile(profile)
        }
    }

    public func predict(board: BoardState, profile: String, nextPlayer: Stone = .black) throws -> ModelOutput {
        let model = try getModel(for: profile)
        let startTime = Date()

        do {
            let modelDescription = (model as? MLModel)?.modelDescription
            let usesNewNaming = modelDescription?.inputDescriptionsByName["spatial_input"] != nil

            let inputDict: [String: Any]
            if usesNewNaming {
                let inputMask = try MLMultiArray(shape: [1, 1, 19, 19], dataType: .float32)
                for i in 0..<(19 * 19) { inputMask[i] = 1.0 }
                inputDict = [
                    "spatial_input": board.spatial,
                    "global_input": board.global,
                    "input_mask": inputMask
                ]
            } else {
                var dict: [String: Any] = [
                    "input_spatial": board.spatial,
                    "input_global": board.global
                ]
                let requiresInputMeta = modelDescription?.inputDescriptionsByName["input_meta"] != nil
                if requiresInputMeta {
                    let profileName: String
                    if isHumanSLProfile(profile) {
                        profileName = "preaz_" + profile
                    } else {
                        profileName = "preaz_20k"
                    }
                    let sgfMeta = SGFMetadata.getProfile(profileName)
                    let metadataRow = SGFMetadata.fillMetadataRow(sgfMeta, nextPlayer: nextPlayer, boardArea: 361)
                    let inputMeta = try MLMultiArray(shape: [1, 192], dataType: .float16)
                    for i in 0..<192 {
                        inputMeta[i] = NSNumber(value: metadataRow[i])
                    }
                    dict["input_meta"] = inputMeta
                }
                inputDict = dict
            }

            let input = try MLDictionaryFeatureProvider(dictionary: inputDict)
            let prediction = try model.prediction(from: input)

            let output: ModelOutput
            if usesNewNaming {
                output = try extractNewModelOutput(from: prediction)
            } else {
                output = try extractOldModelOutput(from: prediction)
            }

            let inferenceTime = Date().timeIntervalSince(startTime)
            ModelStatus.reportInferenceCompleted(time: inferenceTime, policyCount: 362, value: output.whiteWin)

            return output
        } catch let kataError as KataGoError {
            ModelStatus.reportInferenceFailed(error: kataError)
            throw kataError
        } catch {
            ModelStatus.reportInferenceFailed(error: error)
            throw KataGoError.inferenceFailed(error.localizedDescription)
        }
    }

    private func extractOldModelOutput(from prediction: MLFeatureProvider) throws -> ModelOutput {
        guard let policy = prediction.featureValue(for: "output_policy")?.multiArrayValue,
              let valueArray = prediction.featureValue(for: "out_value")?.multiArrayValue,
              let ownership = prediction.featureValue(for: "out_ownership")?.multiArrayValue else {
            throw KataGoError.inferenceFailed("Invalid model outputs")
        }
        let miscValueArray = prediction.featureValue(for: "out_miscvalue")?.multiArrayValue
        let moreMiscValueArray = prediction.featureValue(for: "out_moremiscvalue")?.multiArrayValue
        return ModelOutput(
            policy: policy,
            ownership: ownership,
            valueArray: valueArray,
            miscValueArray: miscValueArray,
            moreMiscValueArray: moreMiscValueArray
        )
    }

    private func extractNewModelOutput(from prediction: MLFeatureProvider) throws -> ModelOutput {
        guard let policyBoard = prediction.featureValue(for: "policy_p2_conv")?.multiArrayValue,
              let policyPass = prediction.featureValue(for: "policy_pass")?.multiArrayValue,
              let valueArray = prediction.featureValue(for: "value_v3_bias")?.multiArrayValue,
              let ownership = prediction.featureValue(for: "value_ownership_conv")?.multiArrayValue else {
            throw KataGoError.inferenceFailed("Invalid model outputs (new naming)")
        }
        // Combine policy_p2_conv [1,2,19,19] and policy_pass [1,2] into [1,6,362]
        let policy = try MLMultiArray(shape: [1, 6, 362], dataType: .float32)
        for i in 0..<policy.count { policy[i] = 0.0 }
        for y in 0..<19 {
            for x in 0..<19 {
                let posIdx = y * 19 + x
                policy[[0, 0, NSNumber(value: posIdx)]] = policyBoard[[0, 0, NSNumber(value: y), NSNumber(value: x)]]
            }
        }
        policy[[0, 0, 361]] = policyPass[[0, 0]]
        // Synthesize miscValueArray [1,10] from value_sv3_bias [1,6]
        let miscValueArray = try MLMultiArray(shape: [1, 10], dataType: .float32)
        for i in 0..<10 { miscValueArray[i] = 0.0 }
        let sv3 = prediction.featureValue(for: "value_sv3_bias")?.multiArrayValue
        if let sv3 {
            miscValueArray[[0, 0]] = sv3[[0, 0]] // scoreMean
            miscValueArray[[0, 1]] = sv3[[0, 1]] // scoreMeanSq
            miscValueArray[[0, 2]] = sv3[[0, 2]] // lead
            miscValueArray[[0, 3]] = sv3[[0, 3]] // varTimeLeft
        }
        // Synthesize moreMiscValueArray [1,8] from value_sv3_bias
        let moreMiscValueArray = try MLMultiArray(shape: [1, 8], dataType: .float32)
        for i in 0..<8 { moreMiscValueArray[i] = 0.0 }
        if let sv3 {
            moreMiscValueArray[[0, 0]] = sv3[[0, 4]] // shorttermWinlossError
            moreMiscValueArray[[0, 1]] = sv3[[0, 5]] // shorttermScoreError
        }
        return ModelOutput(
            policy: policy,
            ownership: ownership,
            valueArray: valueArray,
            miscValueArray: miscValueArray,
            moreMiscValueArray: moreMiscValueArray
        )
    }

    public func rawNN(
        board: Board,
        boardState: BoardState,
        profile: String,
        whichSymmetry: Int = 0,
        policyOptimism _: Float? = nil,
        useHumanModel: Bool = false
    ) throws -> String {
        let nextPlayer: Stone = board.turnNumber % 2 == 0 ? .black : .white
        let output = try predict(board: boardState, profile: profile, nextPlayer: nextPlayer)
        let postProcessParams = PostProcessParams.default
        let postprocessed = output.postprocess(
            board: board,
            nextPlayer: nextPlayer,
            modelVersion: 15,
            postProcessParams: postProcessParams
        )

        var result = ""

        if useHumanModel {
            result += "symmetry \(whichSymmetry)\n"
            result += String(format: "whiteWin %.6f\n", postprocessed.whiteWinProb)
            result += String(format: "whiteLoss %.6f\n", postprocessed.whiteLossProb)
            result += String(format: "noResult %.6f\n", postprocessed.whiteNoResultProb)
            result += String(format: "whiteScore %.3f\n", postprocessed.whiteScoreMean)
            result += String(format: "whiteScoreSq %.3f\n", postprocessed.whiteScoreMeanSq)
            result += String(format: "shorttermWinlossError %.3f\n", postprocessed.shorttermWinlossError)
            result += String(format: "shorttermScoreError %.3f\n", postprocessed.shorttermScoreError)
        } else {
            result += "symmetry \(whichSymmetry)\n"
            result += String(format: "whiteWin %.6f\n", postprocessed.whiteWinProb)
            result += String(format: "whiteLoss %.6f\n", postprocessed.whiteLossProb)
            result += String(format: "noResult %.6f\n", postprocessed.whiteNoResultProb)
            result += String(format: "whiteLead %.3f\n", postprocessed.whiteLead)
            result += String(format: "whiteScoreSelfplay %.3f\n", postprocessed.whiteScoreMean)
            result += String(format: "whiteScoreSelfplaySq %.3f\n", postprocessed.whiteScoreMeanSq)
            result += String(format: "varTimeLeft %.3f\n", postprocessed.varTimeLeft)
            result += String(format: "shorttermWinlossError %.3f\n", postprocessed.shorttermWinlossError)
            result += String(format: "shorttermScoreError %.3f\n", postprocessed.shorttermScoreError)
        }

        result += "policy\n"
        result += formatPolicyGridFromPostprocessed(policyProbs: postprocessed.policyProbs)
        let policyPass = postprocessed.policyProbs[361] >= 0 ? postprocessed.policyProbs[361] : 0.0
        result += String(format: "policyPass %8.6f \n", policyPass)
        result += "whiteOwnership\n"
        result += formatOwnershipGridFromPostprocessed(ownership: postprocessed.ownership)
        result += "\n"

        return result
    }

    private func formatPolicyGridFromPostprocessed(policyProbs: [Float]) -> String {
        var result = ""
        for y in 0..<19 {
            var lineValues: [String] = []
            for x in 0..<19 {
                let positionIndex = y * 19 + x
                let value = positionIndex < policyProbs.count ? policyProbs[positionIndex] : 0.0
                if value < 0 {
                    lineValues.append("    NAN ")
                } else {
                    lineValues.append(String(format: "%8.6f ", value))
                }
            }
            result += lineValues.joined(separator: " ") + "\n"
        }
        return result
    }

    private func formatOwnershipGridFromPostprocessed(ownership: [Float]) -> String {
        var result = ""
        for y in 0..<19 {
            var lineValues: [String] = []
            for x in 0..<19 {
                let positionIndex = y * 19 + x
                let value = positionIndex < ownership.count ? ownership[positionIndex] : 0.0
                if value.isNaN {
                    lineValues.append("     NAN ")
                } else {
                    lineValues.append(String(format: "%9.7f ", value))
                }
            }
            result += lineValues.joined(separator: " ") + "\n"
        }
        return result
    }
}

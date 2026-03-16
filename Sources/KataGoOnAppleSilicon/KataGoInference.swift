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
		guard let suffix = profile.last, suffix == "d" || suffix == "k" else {
			return false
		}
		let numberPart = String(profile.dropLast())
		guard let number = Int(numberPart) else {
			return false
		}
		if suffix == "d" {
			return number >= 1 && number <= 9
		}
		return number >= 1 && number <= 20
	}
	private func getModel(for profile: String) throws -> any ModelProtocol {
		if profile == "AI" {
			guard let model = aiModel else {
				throw KataGoError.modelNotFound("AI model not loaded. Call loadModel(for: \"AI\") first.")
			}
			return model
		}
		if isHumanSLProfile(profile) {
			guard let model = humanSLModel else {
				throw KataGoError.modelNotFound("Human SL model not loaded. Call loadModel(for: \"20k\") or similar first.")
			}
			return model
		}
		guard let model = aiModel else {
			throw KataGoError.modelNotFound("AI model not loaded. Call loadModel(for: \"AI\") first.")
		}
		return model
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
			let requiresInputMeta = modelDescription?.inputDescriptionsByName["input_meta"] != nil
			var inputDict: [String: Any] = [
				"input_spatial": board.spatial,
				"input_global": board.global
			]
			if requiresInputMeta {
				let profileName: String
				if isHumanSLProfile(profile) {
					profileName = "preaz_" + profile
				} else {
					profileName = "preaz_20k"
				}
				let sgfMeta = SGFMetadata.getProfile(profileName)
				let metadataRow = SGFMetadata.fillMetadataRow(sgfMeta, nextPlayer: nextPlayer, boardArea: 361)
				let inputMetaShape: [NSNumber] = [1, 192]
				let inputMeta = try MLMultiArray(shape: inputMetaShape, dataType: .float16)
				for i in 0..<192 {
					inputMeta[i] = NSNumber(value: metadataRow[i])
				}
				inputDict["input_meta"] = inputMeta
			}
			let input = try MLDictionaryFeatureProvider(dictionary: inputDict)
			let prediction = try model.prediction(from: input)
			guard let policy = prediction.featureValue(for: "output_policy")?.multiArrayValue,
				  let valueArray = prediction.featureValue(for: "out_value")?.multiArrayValue,
				  let ownership = prediction.featureValue(for: "out_ownership")?.multiArrayValue else {
				throw KataGoError.inferenceFailed("Invalid model outputs")
			}
			let miscValueArray = prediction.featureValue(for: "out_miscvalue")?.multiArrayValue
			let moreMiscValueArray = prediction.featureValue(for: "out_moremiscvalue")?.multiArrayValue
			let output = ModelOutput(
				policy: policy,
				ownership: ownership,
				valueArray: valueArray,
				miscValueArray: miscValueArray,
				moreMiscValueArray: moreMiscValueArray
			)
			let inferenceTime = Date().timeIntervalSince(startTime)
			ModelStatus.reportInferenceCompleted(time: inferenceTime, policyCount: Int(policy.count), value: output.whiteWin)
			return output
		} catch let kataError as KataGoError {
			ModelStatus.reportInferenceFailed(error: kataError)
			throw kataError
		} catch {
			ModelStatus.reportInferenceFailed(error: error)
			throw KataGoError.inferenceFailed(error.localizedDescription)
		}
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
		let postProcessParams = PostProcessParams(
			outputScaleMultiplier: 1.0,
			scoreMeanMultiplier: 20.0,
			scoreStdevMultiplier: 20.0,
			leadMultiplier: 20.0,
			varianceTimeMultiplier: 40.0,
			shorttermValueErrorMultiplier: 0.25,
			shorttermScoreErrorMultiplier: 150.0
		)
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

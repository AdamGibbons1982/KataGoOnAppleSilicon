import CoreML
import Foundation

/// Protocol for model inference - enables mocking in tests
public protocol ModelProtocol {
    func prediction(from input: MLFeatureProvider) throws -> MLFeatureProvider
}

/// Make MLModel conform to ModelProtocol
extension MLModel: ModelProtocol {}

/// Main class for KataGo inference
public class KataGoInference {
    private let modelLoader = ModelLoader()
    private var models: [String: any ModelProtocol] = [:]
    
    public init() {}
    
    /// Inject a model for testing purposes
    internal func setModel(_ model: any ModelProtocol, for profile: String) {
        models[profile] = model
    }
    
    /// Load a model for a specific profile
    public func loadModel(for profile: String) throws {
        let modelName: String
        switch profile {
        case "AI":
            modelName = "KataGoModel19x19fp16-adam-s11165M"  // Strongest 28b model
        case "9d", "20k":
            modelName = "KataGoModel19x19fp16m1"  // Human SL model
        default:
            throw KataGoError.unsupportedProfile(profile)
        }
        
        let model = try modelLoader.loadModel(name: modelName)
        models[profile] = model
    }
    
    /// Perform inference on the given board state
    public func predict(board: BoardState, profile: String) throws -> ModelOutput {
        guard let model = models[profile] else {
            throw KataGoError.modelNotFound("Model for profile \(profile) not loaded")
        }
        
        let startTime = Date()
        
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_spatial": board.spatial,
                "input_global": board.global
            ])
            let prediction = try model.prediction(from: input)
            
            // Extract outputs - model uses output_policy, out_value, out_ownership
            guard let policy = prediction.featureValue(for: "output_policy")?.multiArrayValue,
                  let valueArray = prediction.featureValue(for: "out_value")?.multiArrayValue,
                  let ownership = prediction.featureValue(for: "out_ownership")?.multiArrayValue else {
                throw KataGoError.inferenceFailed("Invalid model outputs")
            }
            
            // Extract optional misc value arrays
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
            // Re-throw KataGoError without wrapping
            ModelStatus.reportInferenceFailed(error: kataError)
            throw kataError
        } catch {
            // Wrap other errors in KataGoError
            ModelStatus.reportInferenceFailed(error: error)
            throw KataGoError.inferenceFailed(error.localizedDescription)
        }
    }
    
    /// Generate raw neural network output in KataGo format
    /// - Parameters:
    ///   - board: Current board state
    ///   - boardState: BoardState for model input
    ///   - profile: Model profile to use
    ///   - whichSymmetry: Symmetry index (0-7) or 8 for all symmetries
    ///   - policyOptimism: Optional policy optimism value (0.0-1.0), defaults to 0.0
    ///   - useHumanModel: Whether to use human SL model (affects output format)
    /// - Returns: Formatted string matching KataGo's kata-raw-nn output
    public func rawNN(
        board: Board,
        boardState: BoardState,
        profile: String,
        whichSymmetry: Int = 0,
        policyOptimism: Float? = nil,
        useHumanModel: Bool = false
    ) throws -> String {
        // Get model prediction
        let output = try predict(board: boardState, profile: profile)
        
        // Extract value outputs
        let whiteWin = output.whiteWin
        let whiteLoss = output.whiteLoss
        let noResult = output.noResult
        
        // Calculate whiteLead (for regular model)
        let whiteLead = whiteWin - whiteLoss
        
        // Get additional fields (use defaults if not available)
        let whiteScoreSelfplay = output.whiteScoreMean ?? 0.0
        let whiteScoreSelfplaySq = output.whiteScoreMeanSq ?? 0.0
        let varTimeLeft = output.varTimeLeft ?? 0.0
        let shorttermWinlossError = output.shorttermWinlossError ?? 0.0
        let shorttermScoreError = output.shorttermScoreError ?? 0.0
        
        // For human model, use different fields
        let whiteScore = output.whiteScoreMean ?? 0.0
        let whiteScoreSq = output.whiteScoreMeanSq ?? 0.0
        
        // Format output based on model type
        var result = ""
        
        if useHumanModel {
            // Human model format
            result += "symmetry \(whichSymmetry)\n"
            result += String(format: "whiteWin %.6f\n", whiteWin)
            result += String(format: "whiteLoss %.6f\n", whiteLoss)
            result += String(format: "noResult %.6f\n", noResult)
            result += String(format: "whiteScore %.3f\n", whiteScore)
            result += String(format: "whiteScoreSq %.3f\n", whiteScoreSq)
            result += String(format: "shorttermWinlossError %.3f\n", shorttermWinlossError)
            result += String(format: "shorttermScoreError %.3f\n", shorttermScoreError)
        } else {
            // Regular model format
            result += "symmetry \(whichSymmetry)\n"
            result += String(format: "whiteWin %.6f\n", whiteWin)
            result += String(format: "whiteLoss %.6f\n", whiteLoss)
            result += String(format: "noResult %.6f\n", noResult)
            result += String(format: "whiteLead %.3f\n", whiteLead)
            result += String(format: "whiteScoreSelfplay %.3f\n", whiteScoreSelfplay)
            result += String(format: "whiteScoreSelfplaySq %.3f\n", whiteScoreSelfplaySq)
            result += String(format: "varTimeLeft %.3f\n", varTimeLeft)
            result += String(format: "shorttermWinlossError %.3f\n", shorttermWinlossError)
            result += String(format: "shorttermScoreError %.3f\n", shorttermScoreError)
        }
        
        // Format policy grid (19x19)
        result += "policy\n"
        result += formatPolicyGrid(policy: output.policy)
        
        // Format policy pass
        let policyPass = extractPolicyPass(policy: output.policy)
        result += String(format: "policyPass %8.6f \n", policyPass)
        
        // Format ownership grid (19x19)
        result += "whiteOwnership\n"
        result += formatOwnershipGrid(ownership: output.ownership)
        
        // Empty line after symmetry block
        result += "\n"
        
        return result
    }
    
    /// Format policy grid as 19 lines of 19 values each
    private func formatPolicyGrid(policy: MLMultiArray) -> String {
        var result = ""
        
        // Policy shape can be:
        // - [1, 19, 19] - 2D grid
        // - [1, 19, 19, 1] or [1, 19, 19, channels] - 3D grid with channels
        // - [1, 6, 362] - flattened format: 6 channels, 362 positions (361 board + 1 pass)
        let shape = policy.shape.map { $0.intValue }
        let dimCount = shape.count
        
        for y in 0..<19 {
            var lineValues: [String] = []
            for x in 0..<19 {
                let value: Float
                if dimCount == 3 && shape[1] == 6 && shape[2] == 362 {
                    // [1, 6, 362] format - flattened positions with 6 channels
                    // Position index = y * 19 + x (for board positions, 0-360)
                    // Channel 0 is the main policy channel
                    let positionIndex = y * 19 + x
                    value = policy[[0, 0, NSNumber(value: positionIndex)]].floatValue
                } else if dimCount == 4 {
                    // Handle [1, 19, 19, channels] or [1, channels, 19, 19] format
                    if shape[1] == 19 {
                        // [1, 19, 19, channels] - access as [0, y, x, 0]
                        value = policy[[0, NSNumber(value: y), NSNumber(value: x), 0]].floatValue
                    } else {
                        // [1, channels, 19, 19] - access as [0, 0, y, x]
                        value = policy[[0, 0, NSNumber(value: y), NSNumber(value: x)]].floatValue
                    }
                } else if dimCount == 3 && shape[1] == 19 {
                    // [1, 19, 19]
                    value = policy[[0, NSNumber(value: y), NSNumber(value: x)]].floatValue
                } else {
                    // Fallback: try to access as flattened array
                    let index = y * 19 + x
                    if index < policy.count {
                        value = policy[index].floatValue
                    } else {
                        value = 0.0
                    }
                }
                
                if value.isNaN {
                    lineValues.append("    NAN ")
                } else {
                    lineValues.append(String(format: "%8.6f", value))
                }
            }
            result += lineValues.joined(separator: " ") + "\n"
        }
        
        return result
    }
    
    /// Extract policy pass probability
    /// Policy shape is [1, 6, 362] where index 361 is the pass move
    private func extractPolicyPass(policy: MLMultiArray) -> Float {
        let shape = policy.shape.map { $0.intValue }
        let dimCount = shape.count
        
        // Pass move is at position index 361 (362nd position, 0-indexed)
        if dimCount == 3 && shape[1] == 6 && shape[2] == 362 {
            // [1, 6, 362] format - pass is at position index 361, channel 0
            return policy[[0, 0, NSNumber(value: 361)]].floatValue
        } else if dimCount == 4 && shape[1] == 19 && shape[2] == 19 {
            // [1, 19, 19, channels] - pass might be separate or at a different location
            // For now, return 0.0 as pass extraction from this format needs verification
            return 0.0
        } else {
            // Fallback: try to access as flattened array at index 361
            if policy.count > 361 {
                return policy[361].floatValue
            }
            return 0.0
        }
    }
    
    /// Format ownership grid as 19 lines of 19 values each
    private func formatOwnershipGrid(ownership: MLMultiArray) -> String {
        var result = ""
        
        // Ownership shape can be [1, 19, 19] or [1, 1, 19, 19]
        let shape = ownership.shape.map { $0.intValue }
        let is4D = shape.count == 4
        
        for y in 0..<19 {
            var lineValues: [String] = []
            for x in 0..<19 {
                let value: Float
                if is4D {
                    value = ownership[[0, 0, NSNumber(value: y), NSNumber(value: x)]].floatValue
                } else {
                    value = ownership[[0, NSNumber(value: y), NSNumber(value: x)]].floatValue
                }
                
                if value.isNaN {
                    lineValues.append("     NAN ")
                } else {
                    lineValues.append(String(format: "%9.7f", value))
                }
            }
            result += lineValues.joined(separator: " ") + "\n"
        }
        
        return result
    }
}
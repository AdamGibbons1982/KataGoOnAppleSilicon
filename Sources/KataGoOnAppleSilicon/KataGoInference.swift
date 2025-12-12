import CoreML
import Foundation

/// Main class for KataGo inference
public class KataGoInference {
    private let modelLoader = ModelLoader()
    private var models: [String: MLModel] = [:]
    
    public init() {}
    
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
            
            // Extract outputs
            guard let policy = prediction.featureValue(for: "policy")?.multiArrayValue,
                  let valueNum = prediction.featureValue(for: "value")?.doubleValue,
                  let ownership = prediction.featureValue(for: "ownership")?.multiArrayValue else {
                throw KataGoError.inferenceFailed("Invalid model outputs")
            }
            
            let output = ModelOutput(policy: policy, value: Float(valueNum), ownership: ownership)
            
            let inferenceTime = Date().timeIntervalSince(startTime)
            ModelStatus.reportInferenceCompleted(time: inferenceTime, policyCount: Int(policy.count), value: output.value)
            
            return output
        } catch {
            ModelStatus.reportInferenceFailed(error: error)
            throw KataGoError.inferenceFailed(error.localizedDescription)
        }
    }
}
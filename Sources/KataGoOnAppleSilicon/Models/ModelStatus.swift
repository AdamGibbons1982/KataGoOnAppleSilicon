import Foundation

/// Text-based status reporting for model operations
public struct ModelStatus {
    public static func reportModelLoaded(name: String, time: TimeInterval) {
        print("Model '\(name)' loaded successfully in \(String(format: "%.2f", time))s")
    }
    
    public static func reportModelLoadFailed(name: String, error: Error) {
        print("Model '\(name)' load failed: \(error.localizedDescription)")
    }
    
    public static func reportInferenceCompleted(time: TimeInterval, policyCount: Int, value: Float) {
        print("Inference completed in \(String(format: "%.2f", time))s, policy moves: \(policyCount), value: \(String(format: "%.3f", value))")
    }
    
    public static func reportInferenceFailed(error: Error) {
        print("Inference failed: \(error.localizedDescription)")
    }
}
import Foundation

/// Text-based status reporting for model operations
public struct ModelStatus {
    public static func reportModelLoaded(name: String, time: TimeInterval) {
        // Status reporting disabled
    }
    
    public static func reportModelLoadFailed(name: String, error: Error) {
        // Status reporting disabled
    }
    
    public static func reportInferenceCompleted(time: TimeInterval, policyCount: Int, value: Float) {
        // Status reporting disabled
    }
    
    public static func reportInferenceFailed(error: Error) {
        // Status reporting disabled
    }
}
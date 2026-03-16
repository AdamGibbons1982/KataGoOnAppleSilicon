import Foundation
public struct ModelStatus {
	public static func reportModelLoaded(name _: String, time _: TimeInterval) {
	}
	public static func reportModelLoadFailed(name _: String, error _: Error) {
	}
	public static func reportInferenceCompleted(time _: TimeInterval, policyCount _: Int, value _: Float) {
	}
	public static func reportInferenceFailed(error _: Error) {
	}
}

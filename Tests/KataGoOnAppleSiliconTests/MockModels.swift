import CoreML
import Foundation
@testable import KataGoOnAppleSilicon
import Testing
class MockModelWithInvalidOutputs: ModelProtocol {
	func prediction(from _: MLFeatureProvider) throws -> MLFeatureProvider {
		try MLDictionaryFeatureProvider(dictionary: [:])
	}
}
class MockModelThatThrows: ModelProtocol {
	struct MockPredictionError: LocalizedError {
		let message: String
		var errorDescription: String? { message }
	}
	func prediction(from _: MLFeatureProvider) throws -> MLFeatureProvider {
		throw MockPredictionError(message: "Simulated prediction failure")
	}
}
class MockModelWithValidOutputs: ModelProtocol {
	let targetX: Int
	let targetY: Int
	init(targetX: Int = 0, targetY: Int = 0) {
		self.targetX = targetX
		self.targetY = targetY
	}
	func prediction(from _: MLFeatureProvider) throws -> MLFeatureProvider {
		let policyShape: [NSNumber] = [1, 6, 362]
		let policy = try! MLMultiArray(shape: policyShape, dataType: .float32)
		for i in 0..<policy.count {
			policy[i] = 0.0
		}
		let positionIndex = targetY * 19 + targetX
		policy[[0, 0, NSNumber(value: positionIndex)]] = 1.0
		let valueShape: [NSNumber] = [1, 3]
		let value = try! MLMultiArray(shape: valueShape, dataType: .float32)
		value[0] = 0.5
		value[1] = 0.3
		value[2] = 0.2
		let ownershipShape: [NSNumber] = [1, 1, 19, 19]
		let ownership = try! MLMultiArray(shape: ownershipShape, dataType: .float32)
		for i in 0..<ownership.count {
			ownership[i] = 0.0
		}
		return try MLDictionaryFeatureProvider(dictionary: [
			"output_policy": policy,
			"out_value": value,
			"out_ownership": ownership
		])
	}
}

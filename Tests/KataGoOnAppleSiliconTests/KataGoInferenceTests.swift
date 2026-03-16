import CoreML
import Foundation
@testable import KataGoOnAppleSilicon
import Testing
@Test func testKataGoInferenceInitialization() throws {
	_ = KataGoInference()
}
@Test func testLoadModelForAIProfile() throws {
	let katago = KataGoInference()
	try katago.loadModel(for: "AI")
	#expect(Bool(true))
}
@Test func testLoadModelFor9dProfile() throws {
	let katago = KataGoInference()
	try katago.loadModel(for: "9d")
	#expect(Bool(true))
}
@Test func testLoadModelFor20kProfile() throws {
	let katago = KataGoInference()
	try katago.loadModel(for: "20k")
	#expect(Bool(true))
}
@Test func testLoadModelForUnsupportedProfile() throws {
	let katago = KataGoInference()
	#expect(throws: KataGoError.self) {
		try katago.loadModel(for: "unsupported")
	}
}
@Test func testPredictWithoutModelLoaded() throws {
	let katago = KataGoInference()
	let board = Board()
	let boardState = BoardState(board: board)
	do {
		_ = try katago.predict(board: boardState, profile: "AI")
		#expect(Bool(false), "Should have thrown error")
	} catch KataGoError.modelNotFound {
		#expect(Bool(true))
	}
}
@Test func testPredictWithModelLoaded() throws {
	let katago = KataGoInference()
	try katago.loadModel(for: "AI")
	let board = Board()
	let boardState = BoardState(board: board)
	let output = try katago.predict(board: boardState, profile: "AI")
	#expect(!output.policy.isEmpty)
	#expect(!output.ownership.isEmpty)
}
@Test func testPredictWithInvalidModelOutputs() throws {
	let katago = KataGoInference()
	let mockModel = MockModelWithInvalidOutputs()
	katago.setModel(mockModel, for: "test")
	let board = Board()
	let boardState = BoardState(board: board)
	do {
		_ = try katago.predict(board: boardState, profile: "test")
		#expect(Bool(false), "Should have thrown error for invalid outputs")
	} catch let error as KataGoError {
		if case .inferenceFailed(let message) = error {
			#expect(message == "Invalid model outputs")
		} else {
			#expect(Bool(false), "Expected inferenceFailed error")
		}
	}
}
@Test func testPredictWhenModelThrows() throws {
	let katago = KataGoInference()
	let mockModel = MockModelThatThrows()
	katago.setModel(mockModel, for: "test")
	let board = Board()
	let boardState = BoardState(board: board)
	do {
		_ = try katago.predict(board: boardState, profile: "test")
		#expect(Bool(false), "Should have thrown error when model throws")
	} catch let error as KataGoError {
		if case .inferenceFailed(let message) = error {
			#expect(message.contains("Simulated prediction failure"))
		} else {
			#expect(Bool(false), "Expected inferenceFailed error")
		}
	}
}

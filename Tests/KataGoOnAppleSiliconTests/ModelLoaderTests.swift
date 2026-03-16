import CoreML
import Foundation
@testable import KataGoOnAppleSilicon
import Testing
@Test func testModelLoaderInitialization() throws {
	_ = ModelLoader()
}
@Test func testLoadExistingModel() throws {
	let loader = ModelLoader()
	_ = try loader.loadModel(name: "KataGoModel19x19fp16-s12192M")
}
@Test func testLoadNonExistingModel() throws {
	let loader = ModelLoader()
	do {
		_ = try loader.loadModel(name: "NonExistingModel")
		#expect(Bool(false), "Should have thrown error")
	} catch KataGoError.modelNotFound {
		#expect(Bool(true))
	}
}

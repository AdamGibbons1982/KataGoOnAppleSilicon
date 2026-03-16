import CoreML
import Foundation
public class ModelLoader {
	public func loadModel(name: String) throws -> MLModel {
		let startTime = Date()
		// Xcode compiles .mlpackage into .mlmodelc at build time — load directly
		if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
			let model = try MLModel(contentsOf: url)
			let loadTime = Date().timeIntervalSince(startTime)
			ModelStatus.reportModelLoaded(name: name, time: loadTime)
			return model
		}
		// Fall back to uncompiled .mlpackage (SPM resource bundle for standalone testing)
		if let url = Bundle.module.url(forResource: name, withExtension: "mlpackage", subdirectory: "Resources") {
			let compiledURL = try MLModel.compileModel(at: url)
			let model = try MLModel(contentsOf: compiledURL)
			let loadTime = Date().timeIntervalSince(startTime)
			ModelStatus.reportModelLoaded(name: name, time: loadTime)
			return model
		}
		throw KataGoError.modelNotFound(name)
	}
}

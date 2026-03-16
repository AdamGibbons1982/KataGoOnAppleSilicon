import CoreML
import Foundation
public class ModelLoader {
	public func loadModel(name: String) throws -> MLModel {
		let startTime = Date()
		guard let url = Bundle.module.url(forResource: name, withExtension: "mlpackage", subdirectory: "Resources") else {
			throw KataGoError.modelNotFound(name)
		}
		let compiledURL = try MLModel.compileModel(at: url)
		let model = try MLModel(contentsOf: compiledURL)
		let loadTime = Date().timeIntervalSince(startTime)
		ModelStatus.reportModelLoaded(name: name, time: loadTime)
		return model
	}
}

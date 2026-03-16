import CoreML
import Foundation
public class ModelLoader {
	public func loadModel(name: String) throws -> MLModel {
		let startTime = Date()
		guard let url = findModel(name: name) else {
			throw KataGoError.modelNotFound(name)
		}
		let compiledURL = try MLModel.compileModel(at: url)
		let model = try MLModel(contentsOf: compiledURL)
		let loadTime = Date().timeIntervalSince(startTime)
		ModelStatus.reportModelLoaded(name: name, time: loadTime)
		return model
	}
	private func findModel(name: String) -> URL? {
		// Try the host app bundle first (models bundled in the app target)
		if let url = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
			return url
		}
		// Fall back to the SPM resource bundle (for standalone package testing)
		if let url = Bundle.module.url(forResource: name, withExtension: "mlpackage", subdirectory: "Resources") {
			return url
		}
		return nil
	}
}

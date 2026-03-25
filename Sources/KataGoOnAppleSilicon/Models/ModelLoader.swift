import CoreML
import Foundation
public class ModelLoader {
    public func loadModel(name: String) throws -> MLModel {
        let startTime = Date()
        let config = MLModelConfiguration()
        config.computeUnits = .all  // GPU + Neural Engine

        // Prefer runtime compilation from .mlpackage — this triggers full GPU/ANE optimization.
        // Check Bundle.main first (app target resources), then Bundle.module (SPM bundle).
        let mlpackageURL: URL? =
            Bundle.main.url(forResource: name, withExtension: "mlpackage") ??
            Bundle.module.url(forResource: name, withExtension: "mlpackage", subdirectory: "Resources")

        if let url = mlpackageURL {
            print("[ModelLoader] Compiling model from: \(url.lastPathComponent)")
            let compiledURL = try MLModel.compileModel(at: url)
            let model = try MLModel(contentsOf: compiledURL, configuration: config)
            let loadTime = Date().timeIntervalSince(startTime)
            print("[ModelLoader] Compiled and loaded in \(String(format: "%.2f", loadTime))s")
            ModelStatus.reportModelLoaded(name: name, time: loadTime)
            return model
        }
        throw KataGoError.modelNotFound(name)
    }
}

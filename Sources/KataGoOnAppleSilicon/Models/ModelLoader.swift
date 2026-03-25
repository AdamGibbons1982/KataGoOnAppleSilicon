import CoreML
import Foundation
public class ModelLoader {
    public func loadModel(name: String) throws -> MLModel {
        let startTime = Date()
        let config = MLModelConfiguration()
        config.computeUnits = .all  // GPU + Neural Engine

        // Xcode compiles .mlpackage into .mlmodelc at build time — load directly
        if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            print("[ModelLoader] Loading compiled model from Bundle.main: \(url.lastPathComponent)")
            let model = try MLModel(contentsOf: url, configuration: config)
            let loadTime = Date().timeIntervalSince(startTime)
            print("[ModelLoader] Loaded in \(String(format: "%.2f", loadTime))s")
            ModelStatus.reportModelLoaded(name: name, time: loadTime)
            return model
        }
        // Fall back to uncompiled .mlpackage (SPM resource bundle for standalone testing)
        if let url = Bundle.module.url(forResource: name, withExtension: "mlpackage", subdirectory: "Resources") {
            print("[ModelLoader] Compiling model from Bundle.module: \(url.lastPathComponent)")
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

import CoreML
import Foundation
public class ModelLoader {
    public func loadModel(name: String) throws -> MLModel {
        let startTime = Date()
        let config = MLModelConfiguration()
        config.computeUnits = .all  // GPU + Neural Engine

        // Xcode compiles .mlpackage → .mlmodelc at build time and puts it in Bundle.main.
        // Load it with .all compute units to use GPU + ANE.
        if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            print("[ModelLoader] Loading from Bundle.main: \(url.lastPathComponent)")
            let model = try MLModel(contentsOf: url, configuration: config)
            let loadTime = Date().timeIntervalSince(startTime)
            print("[ModelLoader] Loaded in \(String(format: "%.2f", loadTime))s")
            ModelStatus.reportModelLoaded(name: name, time: loadTime)
            return model
        }
        // Fallback: compile from .mlpackage at runtime (SPM standalone testing)
        if let url = Bundle.module.url(forResource: name, withExtension: "mlpackage") {
            print("[ModelLoader] Compiling from Bundle.module: \(url.lastPathComponent)")
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

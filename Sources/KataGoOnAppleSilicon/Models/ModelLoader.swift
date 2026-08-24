import CoreML
import Foundation

/// Loads Core ML models from bundled resources
/// Bundled models:
/// - KataGoModel19x19fp16-adam-s11165M: Strongest 28b model from https://github.com/ChinChangYang/KataGo/releases/download/v1.16.4-coreml1/KataGoModel19x19fp16-adam-s11165M.mlpackage.zip
/// - KataGoModel19x19fp16m1: Human SL model from https://github.com/ChinChangYang/KataGo/releases/download/v1.16.4-coreml1/KataGoModel19x19fp16m1.mlpackage.zip
public class ModelLoader {
    /// Load a model by name from the bundled resources
    public func loadModel(name: String) throws -> MLModel {
        let startTime = Date()

        let config = MLModelConfiguration()
        config.computeUnits = .all

        // A host app that bundles the model ships it as a .mlmodelc, compiled by
        // Xcode at build time into Bundle.main.
        if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            let model = try MLModel(contentsOf: url, configuration: config)
            let loadTime = Date().timeIntervalSince(startTime)
            ModelStatus.reportModelLoaded(name: name, time: loadTime)
            return model
        }

        guard let url = Bundle.module.url(forResource: name, withExtension: "mlpackage", subdirectory: nil) else {
            throw KataGoError.modelNotFound(name)
        }

        let compiledURL = try MLModel.compileModel(at: url)
        let model = try MLModel(contentsOf: compiledURL, configuration: config)
        let loadTime = Date().timeIntervalSince(startTime)
        ModelStatus.reportModelLoaded(name: name, time: loadTime)
        return model
    }
}

import CoreML
import Foundation

/// Loads Core ML models from bundled resources
/// Bundled models:
/// - KataGoModel19x19fp16-adam-s11165M: Strongest 28b model from https://github.com/ChinChangYang/KataGo/releases/download/v1.16.4-coreml1/KataGoModel19x19fp16-adam-s11165M.mlpackage.zip
/// - KataGoModel19x19fp16m1: Human SL model from https://github.com/ChinChangYang/KataGo/releases/download/v1.16.4-coreml1/KataGoModel19x19fp16m1.mlpackage.zip
public class ModelLoader {
    private static let compileLock = NSLock()

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

        ModelLoader.compileLock.lock()
        defer { ModelLoader.compileLock.unlock() }

        let fm = FileManager.default
        let caches = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheFolder = caches.appendingPathComponent("KataGoModels", isDirectory: true)
        if !fm.fileExists(atPath: cacheFolder.path) {
            try fm.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil)
        }

        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString.replacingOccurrences(of: " ", with: "-")
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let modDate = (try? fm.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let cachedModelName = "\(name)-\(osVersion)-\(appVersion)-\(Int(modDate)).mlmodelc"
        let cachedModelURL = cacheFolder.appendingPathComponent(cachedModelName)

        if fm.fileExists(atPath: cachedModelURL.path) {
            if let model = try? MLModel(contentsOf: cachedModelURL, configuration: config) {
                let loadTime = Date().timeIntervalSince(startTime)
                ModelStatus.reportModelLoaded(name: name, time: loadTime)
                return model
            }
            try? fm.removeItem(at: cachedModelURL)
        }

        let compiledURL = try MLModel.compileModel(at: url)
        defer { try? fm.removeItem(at: compiledURL) }

        try? fm.removeItem(at: cachedModelURL)
        try fm.moveItem(at: compiledURL, to: cachedModelURL)

        let model = try MLModel(contentsOf: cachedModelURL, configuration: config)
        let loadTime = Date().timeIntervalSince(startTime)
        ModelStatus.reportModelLoaded(name: name, time: loadTime)
        return model
    }
}

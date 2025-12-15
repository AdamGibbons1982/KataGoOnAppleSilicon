import Foundation
import CoreML

/// Debug utilities for dumping MLMultiArray data to files for comparison
public struct DebugDump {
    
    /// Base directory for debug dumps
    private static var debugDirectory: URL {
        let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let debugDir = projectRoot.appendingPathComponent(".cursor/debug")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true)
        
        return debugDir
    }
    
    /// Dump MLMultiArray to formatted string
    /// - Parameters:
    ///   - array: MLMultiArray to dump
    ///   - name: Name/description for the array
    /// - Returns: Formatted string representation
    public static func dumpMLMultiArray(_ array: MLMultiArray, name: String = "") -> String {
        let shape = array.shape.map { $0.intValue }
        var result = ""
        
        if !name.isEmpty {
            result += "=== \(name) ===\n"
        }
        result += "Shape: \(shape)\n"
        result += "Total elements: \(array.count)\n"
        result += "Data type: \(array.dataType)\n\n"
        
        if shape.count == 4 && shape[0] == 1 {
            // [1, C, H, W] or [1, H, W, C] format - dump plane by plane
            let channels = shape[1]
            let height = shape.count == 4 ? shape[2] : shape[1]
            let width = shape.count == 4 ? shape[3] : shape[2]
            
            for c in 0..<channels {
                result += "Plane \(c):\n"
                for y in 0..<height {
                    var lineValues: [String] = []
                    for x in 0..<width {
                        let value = array[[0, NSNumber(value: c), NSNumber(value: y), NSNumber(value: x)]].floatValue
                        lineValues.append(String(format: "%.6f", value))
                    }
                    result += "  \(lineValues.joined(separator: " "))\n"
                }
                result += "\n"
            }
        } else if shape.count == 3 && shape[0] == 1 {
            // [1, C, N] format (e.g., policy [1, 6, 362])
            let channels = shape[1]
            let elements = shape[2]
            
            for c in 0..<channels {
                result += "Channel \(c):\n"
                var lineValues: [String] = []
                for i in 0..<elements {
                    let value = array[[0, NSNumber(value: c), NSNumber(value: i)]].floatValue
                    lineValues.append(String(format: "%.6f", value))
                    if (i + 1) % 19 == 0 {
                        result += "  \(lineValues.joined(separator: " "))\n"
                        lineValues.removeAll()
                    }
                }
                if !lineValues.isEmpty {
                    result += "  \(lineValues.joined(separator: " "))\n"
                }
                result += "\n"
            }
        } else if shape.count == 2 && shape[0] == 1 {
            // [1, N] format (e.g., global features [1, 19])
            result += "Values:\n"
            var lineValues: [String] = []
            for i in 0..<shape[1] {
                let value = array[[0, NSNumber(value: i)]].floatValue
                lineValues.append(String(format: "%.6f", value))
            }
            result += "  \(lineValues.joined(separator: " "))\n"
        } else {
            // Fallback: dump all values
            result += "Values:\n"
            var lineValues: [String] = []
            for i in 0..<array.count {
                lineValues.append(String(format: "%.6f", array[i].floatValue))
                if (i + 1) % 19 == 0 {
                    result += "  \(lineValues.joined(separator: " "))\n"
                    lineValues.removeAll()
                }
            }
            if !lineValues.isEmpty {
                result += "  \(lineValues.joined(separator: " "))\n"
            }
        }
        
        return result
    }
    
    /// Write string to debug file
    private static func writeToFile(_ content: String, filename: String) {
        let fileURL = debugDirectory.appendingPathComponent(filename)
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }.string(from: Date())
        
        let header = "=== Debug Dump: \(filename) ===\n"
        let timestampLine = "Generated at: \(timestamp)\n\n"
        let fullContent = header + timestampLine + content
        
        try? fullContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    /// Dump raw inputs (spatial and global features)
    public static func dumpRawInputs(spatial: MLMultiArray, global: MLMultiArray) {
        let spatialDump = dumpMLMultiArray(spatial, name: "Spatial Features")
        writeToFile(spatialDump, filename: "swift_inputs_spatial.txt")
        
        let globalDump = dumpMLMultiArray(global, name: "Global Features")
        writeToFile(globalDump, filename: "swift_inputs_global.txt")
    }
    
    /// Dump raw model outputs
    public static func dumpRawOutputs(
        policy: MLMultiArray,
        value: MLMultiArray,
        ownership: MLMultiArray,
        miscValue: MLMultiArray? = nil,
        moreMiscValue: MLMultiArray? = nil
    ) {
        let policyDump = dumpMLMultiArray(policy, name: "Raw Policy Output")
        writeToFile(policyDump, filename: "swift_raw_policy.txt")
        
        let valueDump = dumpMLMultiArray(value, name: "Raw Value Output")
        writeToFile(valueDump, filename: "swift_raw_value.txt")
        
        let ownershipDump = dumpMLMultiArray(ownership, name: "Raw Ownership Output")
        writeToFile(ownershipDump, filename: "swift_raw_ownership.txt")
        
        if let miscValue = miscValue {
            let miscDump = dumpMLMultiArray(miscValue, name: "Raw MiscValue Output")
            writeToFile(miscDump, filename: "swift_raw_miscvalue.txt")
        }
        
        if let moreMiscValue = moreMiscValue {
            let moreMiscDump = dumpMLMultiArray(moreMiscValue, name: "Raw MoreMiscValue Output")
            writeToFile(moreMiscDump, filename: "swift_raw_moremiscvalue.txt")
        }
    }
    
    /// Dump postprocessed outputs
    public static func dumpPostprocessedOutputs(
        policyProbs: [Float],
        ownership: [Float],
        whiteWinProb: Double,
        whiteLossProb: Double,
        whiteNoResultProb: Double,
        whiteScoreMean: Double,
        whiteScoreMeanSq: Double,
        whiteLead: Double,
        varTimeLeft: Double,
        shorttermWinlossError: Double,
        shorttermScoreError: Double
    ) {
        // Dump policy probabilities
        var policyDump = "=== Postprocessed Policy Probabilities ===\n"
        policyDump += "Shape: [362] (361 board positions + 1 pass)\n\n"
        
        // Format as 19x19 grid for board positions
        for y in 0..<19 {
            var lineValues: [String] = []
            for x in 0..<19 {
                let index = y * 19 + x
                let value = index < policyProbs.count ? policyProbs[index] : 0.0
                lineValues.append(String(format: "%.6f", value))
            }
            policyDump += "\(lineValues.joined(separator: " "))\n"
        }
        
        // Add pass move
        let passValue = policyProbs.count > 361 ? policyProbs[361] : 0.0
        policyDump += "\nPass: \(String(format: "%.6f", passValue))\n"
        
        writeToFile(policyDump, filename: "swift_postprocessed_policy.txt")
        
        // Dump ownership
        var ownershipDump = "=== Postprocessed Ownership ===\n"
        ownershipDump += "Shape: [361] (19x19 board)\n\n"
        
        for y in 0..<19 {
            var lineValues: [String] = []
            for x in 0..<19 {
                let index = y * 19 + x
                let value = index < ownership.count ? ownership[index] : 0.0
                lineValues.append(String(format: "%.9f", value))
            }
            ownershipDump += "\(lineValues.joined(separator: " "))\n"
        }
        
        writeToFile(ownershipDump, filename: "swift_postprocessed_ownership.txt")
        
        // Dump value statistics
        var valueDump = "=== Postprocessed Value Statistics ===\n"
        valueDump += String(format: "whiteWin: %.6f\n", whiteWinProb)
        valueDump += String(format: "whiteLoss: %.6f\n", whiteLossProb)
        valueDump += String(format: "whiteNoResult: %.6f\n", whiteNoResultProb)
        valueDump += String(format: "whiteScoreMean: %.3f\n", whiteScoreMean)
        valueDump += String(format: "whiteScoreMeanSq: %.3f\n", whiteScoreMeanSq)
        valueDump += String(format: "whiteLead: %.3f\n", whiteLead)
        valueDump += String(format: "varTimeLeft: %.3f\n", varTimeLeft)
        valueDump += String(format: "shorttermWinlossError: %.3f\n", shorttermWinlossError)
        valueDump += String(format: "shorttermScoreError: %.3f\n", shorttermScoreError)
        
        writeToFile(valueDump, filename: "swift_postprocessed_value.txt")
    }
}

// Helper extension for DateFormatter
private extension DateFormatter {
    func apply(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self)
        return self
    }
}


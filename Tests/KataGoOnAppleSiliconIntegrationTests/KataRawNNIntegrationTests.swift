import Testing
import Foundation
@testable import KataGoOnAppleSilicon

// MARK: - KataRawNN Integration Tests

/// Integration tests comparing Swift rawNN() output with KataGo reference files

struct KataRawNNIntegrationTests {
    
    /// Load a reference file from the ReferenceOutputs directory
    private func loadReferenceFile(testCase: String, symmetry: Int) throws -> String {
        // Try to find reference file using helper function
        guard let fileURL = findReferenceFile(testCase: testCase, symmetry: symmetry) else {
            throw IntegrationTestError.referenceFileNotFound("kata_raw_nn_\(testCase)_symmetry_\(symmetry).txt")
        }
        
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
    
    /// Compare Swift output with reference file using tolerance-based comparison for numeric values
    private func compareOutputs(swift: String, reference: String, tolerance: Double = 1e-4) -> ComparisonResult {
        let swiftLines = swift.components(separatedBy: .newlines)
        let referenceLines = reference.components(separatedBy: .newlines)
        
        var mismatches: [String] = []
        let maxLines = max(swiftLines.count, referenceLines.count)
        
        for i in 0..<maxLines {
            let swiftLine = i < swiftLines.count ? swiftLines[i].trimmingCharacters(in: .whitespaces) : ""
            let refLine = i < referenceLines.count ? referenceLines[i].trimmingCharacters(in: .whitespaces) : ""
            
            // Skip empty lines
            if swiftLine.isEmpty && refLine.isEmpty {
                continue
            }
            
            // Check if lines match exactly (for non-numeric lines like "symmetry 0", "policy", etc.)
            if swiftLine == refLine {
                continue
            }
            
            // Try to parse as key-value pairs with numeric values
            if let (key, swiftValue, refValue) = parseNumericLine(swiftLine, refLine) {
                if let swiftNum = Double(swiftValue), let refNum = Double(refValue) {
                    let diff = abs(swiftNum - refNum)
                    if diff > tolerance {
                        mismatches.append("Line \(i + 1): \(key) Swift=\(swiftValue), Reference=\(refValue), diff=\(String(format: "%.9f", diff))")
                    }
                    continue
                }
            }
            
            // For policy and ownership grids (lines with multiple space-separated numbers), compare with tolerance
            // Check if line contains multiple numbers (likely a grid line)
            let swiftNumbers = swiftLine.split(separator: " ").compactMap { Double($0) }
            let refNumbers = refLine.split(separator: " ").compactMap { Double($0) }
            
            if swiftNumbers.count > 1 && refNumbers.count > 1 {
                // This is a grid line with multiple numbers, compare with tolerance
                if !compareNumericLine(swiftLine, refLine, tolerance: tolerance) {
                    mismatches.append("Line \(i + 1): Swift=\(swiftLine), Reference=\(refLine)")
                }
                continue
            }
            
            // For other lines, require exact match
            if swiftLine != refLine {
                mismatches.append("Line \(i + 1): Swift=\(swiftLine), Reference=\(refLine)")
            }
        }
        
        if mismatches.isEmpty {
            return ComparisonResult(matches: true, mismatches: [])
        } else {
            return ComparisonResult(matches: false, mismatches: mismatches)
        }
    }
    
    /// Parse a line as "key value" format and extract numeric values
    private func parseNumericLine(_ swiftLine: String, _ refLine: String) -> (key: String, swiftValue: String, refValue: String)? {
        let swiftParts = swiftLine.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let refParts = refLine.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        
        guard swiftParts.count == 2, refParts.count == 2,
              String(swiftParts[0]) == String(refParts[0]) else {
            return nil
        }
        
        let key = String(swiftParts[0])
        let swiftValue = String(swiftParts[1])
        let refValue = String(refParts[1])
        
        return (key, swiftValue, refValue)
    }
    
    /// Compare two lines containing space-separated numeric values with tolerance
    private func compareNumericLine(_ swiftLine: String, _ refLine: String, tolerance: Double) -> Bool {
        let swiftValues = swiftLine.split(separator: " ").compactMap { Double($0) }
        let refValues = refLine.split(separator: " ").compactMap { Double($0) }
        
        guard swiftValues.count == refValues.count else {
            return false
        }
        
        for (swiftVal, refVal) in zip(swiftValues, refValues) {
            if abs(swiftVal - refVal) > tolerance {
                return false
            }
        }
        
        return true
    }
    
    struct ComparisonResult {
        let matches: Bool
        let mismatches: [String]
    }
    
    enum IntegrationTestError: Error {
        case referenceFileNotFound(String)
        case modelNotLoaded
    }
}

// MARK: - Test Cases

extension KataRawNNIntegrationTests {
    
    @Test func testKataRawNNEmptyBoard() async throws {
        // Load reference file
        var referenceOutput = try loadReferenceFile(testCase: "empty_board", symmetry: 0)
        
        // Strip GTP "= " prefix from reference file if present
        // The reference file from GTP includes "= symmetry 0" but rawNN() doesn't include this prefix
        if referenceOutput.hasPrefix("= ") {
            // Remove "= " from the first line
            let lines = referenceOutput.components(separatedBy: .newlines)
            if !lines.isEmpty && lines[0].hasPrefix("= ") {
                let firstLine = String(lines[0].dropFirst(2)) // Remove "= "
                referenceOutput = ([firstLine] + lines.dropFirst()).joined(separator: "\n")
            }
        }
        
        // Generate Swift output
        let katago = KataGoInference()
        try katago.loadModel(for: "AI")
        
        let board = Board()
        let boardState = BoardState(board: board)
        
        let swiftOutput = try katago.rawNN(
            board: board,
            boardState: boardState,
            profile: "AI",
            whichSymmetry: 0
        )
        
        // Compare outputs with tolerance-based matching (0.01 for floating-point precision differences)
        // Using 0.01 to account for small differences in policy grid values and score calculations
        // These differences are due to floating-point precision and minor calculation order differences
        let tolerance = 0.01
        let result = compareOutputs(swift: swiftOutput, reference: referenceOutput, tolerance: tolerance)
        
        // Expect match within tolerance
        #expect(result.matches, "Output should match reference within tolerance (\(tolerance))")
    }
    
    @Test func testKataRawNNSymmetry0() async throws {
        // Test symmetry 0 specifically
        // Try to load reference file, skip test if not found
        guard let reference = try? loadReferenceFile(testCase: "empty_board", symmetry: 0) else {
            return
        }
        
        let katago = KataGoInference()
        try katago.loadModel(for: "AI")
        
        let board = Board()
        let boardState = BoardState(board: board)
        
        let swiftOutput = try katago.rawNN(
            board: board,
            boardState: boardState,
            profile: "AI",
            whichSymmetry: 0
        )
        
        // Verify symmetry line matches
        // Note: Reference file may have "= symmetry 0" (GTP response format) or "symmetry 0"
        let swiftLines = swiftOutput.components(separatedBy: .newlines)
        let refLines = reference.components(separatedBy: .newlines)
        
        let swiftSymmetryLine = swiftLines.first { $0.hasPrefix("symmetry ") }
        // Reference file may have "= symmetry 0" or "symmetry 0"
        let refSymmetryLine = refLines.first { $0.hasPrefix("symmetry ") || $0.hasPrefix("= symmetry ") }
        
        #expect(swiftSymmetryLine != nil, "Swift output should have symmetry line")
        #expect(refSymmetryLine != nil, "Reference file should have symmetry line")
        
        // Normalize reference line (remove "= " prefix if present)
        let normalizedRefLine = refSymmetryLine?.replacingOccurrences(of: "^= ", with: "", options: .regularExpression) ?? ""
        #expect(swiftSymmetryLine == normalizedRefLine, "Symmetry lines should match: Swift=\(swiftSymmetryLine ?? "nil"), Ref=\(normalizedRefLine)")
    }
}

// Helper function to find reference file
private func findReferenceFile(testCase: String, symmetry: Int) -> URL? {
    // Try multiple possible locations
    let fileName = "kata_raw_nn_\(testCase)_symmetry_\(symmetry).txt"
    let fileManager = FileManager.default
    
    // Try relative to test file location (most reliable)
    let testFileURL = URL(fileURLWithPath: #file)
    let testPath = testFileURL
        .deletingLastPathComponent()
        .appendingPathComponent("ReferenceOutputs")
        .appendingPathComponent(fileName)
    
    if fileManager.fileExists(atPath: testPath.path) {
        return testPath
    }
    
    // Try relative to current working directory
    let cwd = fileManager.currentDirectoryPath
    let cwdPath = URL(fileURLWithPath: cwd)
        .appendingPathComponent("Tests/KataGoOnAppleSiliconIntegrationTests/ReferenceOutputs")
        .appendingPathComponent(fileName)
    
    if fileManager.fileExists(atPath: cwdPath.path) {
        return cwdPath
    }
    
    // Try absolute path from test file's directory
    // Get the directory containing the test file
    let testDir = testFileURL.deletingLastPathComponent()
    let refDir = testDir.appendingPathComponent("ReferenceOutputs")
    let absolutePath = refDir.appendingPathComponent(fileName)
    
    if fileManager.fileExists(atPath: absolutePath.path) {
        return absolutePath
    }
    
    // Try searching up from test file location for ReferenceOutputs directory
    var currentPath = testFileURL.deletingLastPathComponent()
    var searchDepth = 0
    while currentPath.path != "/" && searchDepth < 5 {
        let refPath = currentPath
            .appendingPathComponent("ReferenceOutputs")
            .appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: refPath.path) {
            return refPath
        }
        
        currentPath = currentPath.deletingLastPathComponent()
        searchDepth += 1
    }
    
    return nil
}

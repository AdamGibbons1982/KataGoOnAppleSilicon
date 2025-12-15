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
            // Debug: Print attempted paths
            let fileName = "kata_raw_nn_\(testCase)_symmetry_\(symmetry).txt"
            let cwd = FileManager.default.currentDirectoryPath
            let testFileURL = URL(fileURLWithPath: #file)
            print("DEBUG: Could not find reference file: \(fileName)")
            print("DEBUG: Current working directory: \(cwd)")
            print("DEBUG: Test file location: \(testFileURL.path)")
            print("DEBUG: Attempted path 1: \(cwd)/Tests/KataGoOnAppleSiliconIntegrationTests/ReferenceOutputs/\(fileName)")
            print("DEBUG: Attempted path 2: \(testFileURL.deletingLastPathComponent().path)/ReferenceOutputs/\(fileName)")
            throw IntegrationTestError.referenceFileNotFound("kata_raw_nn_\(testCase)_symmetry_\(symmetry).txt")
        }
        
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
    
    /// Compare Swift output with reference file, allowing for floating point tolerance
    private func compareOutputs(swift: String, reference: String, tolerance: Float = 0.0001) -> ComparisonResult {
        let swiftLines = swift.components(separatedBy: .newlines)
        let referenceLines = reference.components(separatedBy: .newlines)
        
        var mismatches: [String] = []
        let maxLines = max(swiftLines.count, referenceLines.count)
        
        for i in 0..<maxLines {
            let swiftLine = i < swiftLines.count ? swiftLines[i] : ""
            let refLine = i < referenceLines.count ? referenceLines[i] : ""
            
            if swiftLine != refLine {
                // Try to compare as floating point values if both lines contain numbers
                let swiftFloats = parseFloatLine(swiftLine)
                let refFloats = parseFloatLine(refLine)
                
                if !swiftFloats.isEmpty && !refFloats.isEmpty {
                    // Compare all float values on the line
                    if swiftFloats.count == refFloats.count {
                        var lineMatches = true
                        var maxDiff: Float = 0.0
                        for j in 0..<swiftFloats.count {
                            let diff = abs(swiftFloats[j] - refFloats[j])
                            maxDiff = max(maxDiff, diff)
                            if diff > tolerance {
                                lineMatches = false
                            }
                        }
                        if !lineMatches {
                            mismatches.append("Line \(i + 1): Max diff=\(maxDiff), Swift=\(swiftLine.prefix(80)), Reference=\(refLine.prefix(80))")
                        }
                    } else {
                        // Different number of values
                        mismatches.append("Line \(i + 1): Value count mismatch (Swift=\(swiftFloats.count), Ref=\(refFloats.count))")
                    }
                } else {
                    // Exact string comparison for non-numeric lines
                    mismatches.append("Line \(i + 1): Swift=\(swiftLine), Reference=\(refLine)")
                }
            }
        }
        
        if mismatches.isEmpty {
            return ComparisonResult(matches: true, mismatches: [])
        } else {
            return ComparisonResult(matches: false, mismatches: mismatches)
        }
    }
    
    /// Parse a line that might contain float values (returns all floats found)
    private func parseFloatLine(_ line: String) -> [Float] {
        let components = line.split(separator: " ")
        var floats: [Float] = []
        for component in components {
            if let value = Float(component) {
                floats.append(value)
            }
        }
        return floats
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
        
        // Compare outputs with exact matching (tolerance for floating-point values)
        let result = compareOutputs(swift: swiftOutput, reference: referenceOutput, tolerance: 0.000001)
        
        if !result.matches {
            print("Mismatches found:")
            for mismatch in result.mismatches.prefix(20) {
                print("  \(mismatch)")
            }
            if result.mismatches.count > 20 {
                print("  ... and \(result.mismatches.count - 20) more mismatches")
            }
        }
        
        // Expect exact match (within floating-point tolerance)
        #expect(result.matches, "Output should match reference exactly (within tolerance)")
    }
    
    @Test func testKataRawNNSymmetry0() async throws {
        // Test symmetry 0 specifically
        // Try to load reference file, skip test if not found
        guard let reference = try? loadReferenceFile(testCase: "empty_board", symmetry: 0) else {
            print("Reference file not found, skipping test")
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

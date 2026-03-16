import Foundation
@testable import KataGoOnAppleSilicon
import Testing
struct KataRawNNIntegrationTests {
	private func loadReferenceFile(testCase: String, symmetry: Int) throws -> String {
		guard let fileURL = findReferenceFile(testCase: testCase, symmetry: symmetry) else {
			throw IntegrationTestError.referenceFileNotFound("kata_raw_nn_\(testCase)_symmetry_\(symmetry).txt")
		}
		return try String(contentsOf: fileURL, encoding: .utf8)
	}
	private func compareOutputs(swift: String, reference: String, tolerance: Double = 1e-4) -> ComparisonResult {
		let swiftLines = swift.components(separatedBy: .newlines)
		let referenceLines = reference.components(separatedBy: .newlines)
		var mismatches: [String] = []
		let maxLines = max(swiftLines.count, referenceLines.count)
		for i in 0..<maxLines {
			let swiftLine = i < swiftLines.count ? swiftLines[i].trimmingCharacters(in: .whitespaces) : ""
			let refLine = i < referenceLines.count ? referenceLines[i].trimmingCharacters(in: .whitespaces) : ""
			if swiftLine.isEmpty && refLine.isEmpty {
				continue
			}
			if swiftLine == refLine {
				continue
			}
			if let (key, swiftValue, refValue) = parseNumericLine(swiftLine, refLine) {
				if let swiftNum = Double(swiftValue), let refNum = Double(refValue) {
					let absSwift = abs(swiftNum)
					let absRef = abs(refNum)
					let maxAbs = max(absSwift, absRef, 1.0)
					let relativeDiff = abs(swiftNum - refNum) / maxAbs
					if relativeDiff > tolerance {
						let absDiff = abs(swiftNum - refNum)
						mismatches.append("Line \(i + 1): \(key) Swift=\(swiftValue), Reference=\(refValue), absDiff=\(String(format: "%.9f", absDiff)), relDiff=\(String(format: "%.9f", relativeDiff))")
					}
					continue
				}
			}
			let swiftNumbers = swiftLine.split(separator: " ").compactMap { Double($0) }
			let refNumbers = refLine.split(separator: " ").compactMap { Double($0) }
			if swiftNumbers.count > 1 && refNumbers.count > 1 {
				if !compareNumericLine(swiftLine, refLine, tolerance: tolerance) {
					mismatches.append("Line \(i + 1): Swift=\(swiftLine), Reference=\(refLine)")
				}
				continue
			}
			if swiftLine != refLine {
				mismatches.append("Line \(i + 1): Swift=\(swiftLine), Reference=\(refLine)")
			}
		}
		if mismatches.isEmpty {
			return ComparisonResult(matches: true, mismatches: [])
		}
		return ComparisonResult(matches: false, mismatches: mismatches)
	}
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
	private func compareNumericLine(_ swiftLine: String, _ refLine: String, tolerance: Double) -> Bool {
		let swiftValues = swiftLine.split(separator: " ").compactMap { Double($0) }
		let refValues = refLine.split(separator: " ").compactMap { Double($0) }
		guard swiftValues.count == refValues.count else {
			return false
		}
		for (swiftVal, refVal) in zip(swiftValues, refValues) {
			let absSwift = abs(swiftVal)
			let absRef = abs(refVal)
			let maxAbs = max(absSwift, absRef, 1.0)
			let relativeDiff = abs(swiftVal - refVal) / maxAbs
			if relativeDiff > tolerance {
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
extension KataRawNNIntegrationTests {
	@Test func testKataRawNNEmptyBoard() throws {
		var referenceOutput = try loadReferenceFile(testCase: "empty_board", symmetry: 0)
		if referenceOutput.hasPrefix("= ") {
			let lines = referenceOutput.components(separatedBy: .newlines)
			if !lines.isEmpty && lines[0].hasPrefix("= ") {
				let firstLine = String(lines[0].dropFirst(2))
				referenceOutput = ([firstLine] + lines.dropFirst()).joined(separator: "\n")
			}
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
		let tolerance = 0.01
		let result = compareOutputs(swift: swiftOutput, reference: referenceOutput, tolerance: tolerance)
		#expect(result.matches, "Output should match reference within tolerance (\(tolerance))")
	}
	@Test func testKataRawNNSymmetry0() throws {
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
		let swiftLines = swiftOutput.components(separatedBy: .newlines)
		let refLines = reference.components(separatedBy: .newlines)
		let swiftSymmetryLine = swiftLines.first { $0.hasPrefix("symmetry ") }
		let refSymmetryLine = refLines.first { $0.hasPrefix("symmetry ") || $0.hasPrefix("= symmetry ") }
		#expect(swiftSymmetryLine != nil, "Swift output should have symmetry line")
		#expect(refSymmetryLine != nil, "Reference file should have symmetry line")
		let normalizedRefLine = refSymmetryLine?.replacingOccurrences(of: "^= ", with: "", options: .regularExpression) ?? ""
		#expect(swiftSymmetryLine == normalizedRefLine, "Symmetry lines should match: Swift=\(swiftSymmetryLine ?? "nil"), Ref=\(normalizedRefLine)")
	}
	@Test func testKataRawNNEmptyBoard20k() throws {
		var referenceOutput = try loadReferenceFile(testCase: "empty_board_20k", symmetry: 0)
		if referenceOutput.hasPrefix("= ") {
			let lines = referenceOutput.components(separatedBy: .newlines)
			if !lines.isEmpty && lines[0].hasPrefix("= ") {
				let firstLine = String(lines[0].dropFirst(2))
				referenceOutput = ([firstLine] + lines.dropFirst()).joined(separator: "\n")
			}
		}
		let katago = KataGoInference()
		try katago.loadModel(for: "20k")
		let board = Board()
		let boardState = BoardState(board: board)
		let swiftOutput = try katago.rawNN(
			board: board,
			boardState: boardState,
			profile: "20k",
			whichSymmetry: 0,
			useHumanModel: false
		)
		let tolerance = 0.001
		let result = compareOutputs(swift: swiftOutput, reference: referenceOutput, tolerance: tolerance)
		#expect(result.matches, "Output should match reference within relative tolerance (\(tolerance) = \(tolerance * 100)%)")
	}
}
private func findReferenceFile(testCase: String, symmetry: Int) -> URL? {
	let fileName: String
	if testCase.hasSuffix("_20k") {
		let baseTestCase = String(testCase.dropLast(4))
		fileName = "kata_raw_nn_\(baseTestCase)_symmetry_\(symmetry)_20k.txt"
	} else {
		fileName = "kata_raw_nn_\(testCase)_symmetry_\(symmetry).txt"
	}
	let fileManager = FileManager.default
	let testFileURL = URL(fileURLWithPath: #file)
	let testPath = testFileURL
		.deletingLastPathComponent()
		.appendingPathComponent("ReferenceOutputs")
		.appendingPathComponent(fileName)
	if fileManager.fileExists(atPath: testPath.path) {
		return testPath
	}
	let cwd = fileManager.currentDirectoryPath
	let cwdPath = URL(fileURLWithPath: cwd)
		.appendingPathComponent("Tests/KataGoOnAppleSiliconIntegrationTests/ReferenceOutputs")
		.appendingPathComponent(fileName)
	if fileManager.fileExists(atPath: cwdPath.path) {
		return cwdPath
	}
	let testDir = testFileURL.deletingLastPathComponent()
	let refDir = testDir.appendingPathComponent("ReferenceOutputs")
	let absolutePath = refDir.appendingPathComponent(fileName)
	if fileManager.fileExists(atPath: absolutePath.path) {
		return absolutePath
	}
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

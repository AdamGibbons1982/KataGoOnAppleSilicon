import Foundation
@testable import KataGoOnAppleSilicon
import Testing
@Suite("Game Generator Tests")
struct GameGeneratorTests {
	@Test("Generate 10-move game and export to SGF")
	func testGenerateGame() throws {
		print("\n=== KataGo Game Generator Test ===")
		print("Generating a 10-move game for debugging...\n")
		let katago = KataGoInference()
		try katago.loadModel(for: "AI")
		print("✓ AI model loaded\n")
		let gtp = GTPHandler(katago: katago)
		_ = gtp.handleCommand("clear_board")
		var moves: [(Stone, Point)] = []
		print("Move | Color | GTP Coord | SGF Coord")
		print("-----|-------|-----------|----------")
		for moveNum in 1...10 {
			let color = moveNum % 2 == 1 ? "black" : "white"
			let stone: Stone = color == "black" ? .black : .white
			let response = gtp.handleCommand("genmove \(color)")
			if response.starts(with: "=") {
				let moveStr = response
					.replacingOccurrences(of: "=", with: "")
					.trimmingCharacters(in: .whitespacesAndNewlines)
				let sgfCoord = SGFGenerator.gtpToSgf(moveStr)
				if let point = parseGTPMove(moveStr) {
					moves.append((stone, point))
					let colorStr = color == "black" ? "Black" : "White"
					let moveNumStr = String(format: "%4d", moveNum)
					print("\(moveNumStr) | \(colorStr.padding(toLength: 5, withPad: " ", startingAt: 0)) | \(moveStr.padding(toLength: 9, withPad: " ", startingAt: 0)) | \(sgfCoord)")
				} else {
					Issue.record("Failed to parse move \(moveStr)")
					return
				}
			} else {
				Issue.record("Error generating move \(moveNum): \(response)")
				return
			}
		}
		print("\n=== Generating SGF ===")
		let sgf = SGFGenerator.generateSGF(
			moves: moves,
			blackPlayer: "KataGo (Black)",
			whitePlayer: "KataGo (White)",
			komi: 7.5
		)
		let fileManager = FileManager.default
		let buildOutputDir = ".build/test-output"
		try fileManager.createDirectory(atPath: buildOutputDir, withIntermediateDirectories: true, attributes: nil)
		let timestamp = Int(Date().timeIntervalSince1970)
		let filename = "\(buildOutputDir)/game_\(timestamp).sgf"
		try SGFGenerator.saveSGF(sgf, to: filename)
		print("✓ SGF file saved: \(filename)")
		print("\nSGF Content:")
		print(sgf)
		#expect(sgf.hasPrefix("(;FF[4]GM[1]SZ[19]"))
		#expect(sgf.contains("PB[KataGo (Black)]"))
		#expect(sgf.contains("PW[KataGo (White)]"))
		#expect(sgf.contains("KM[7.5]"))
		#expect(sgf.hasSuffix(")"))
		print("\n✓ Game generation test passed")
	}
	@Test("Generate 10-move game with 20k model and export to SGF")
	func testGenerateGameWith20kModel() throws {
		print("\n=== KataGo Game Generator Test (20k Model) ===")
		print("Generating a 10-move game with 20k human SL model...\n")
		let katago = KataGoInference()
		try katago.loadModel(for: "20k")
		print("✓ 20k model loaded\n")
		let gtp = GTPHandler(katago: katago)
		gtp.setProfile("20k")
		_ = gtp.handleCommand("clear_board")
		var moves: [(Stone, Point)] = []
		print("Move | Color | GTP Coord | SGF Coord")
		print("-----|-------|-----------|----------")
		for moveNum in 1...10 {
			let color = moveNum % 2 == 1 ? "black" : "white"
			let stone: Stone = color == "black" ? .black : .white
			let response = gtp.handleCommand("genmove \(color)")
			if response.starts(with: "=") {
				let moveStr = response
					.replacingOccurrences(of: "=", with: "")
					.trimmingCharacters(in: .whitespacesAndNewlines)
				let sgfCoord = SGFGenerator.gtpToSgf(moveStr)
				if let point = parseGTPMove(moveStr) {
					moves.append((stone, point))
					let colorStr = color == "black" ? "Black" : "White"
					let moveNumStr = String(format: "%4d", moveNum)
					print("\(moveNumStr) | \(colorStr.padding(toLength: 5, withPad: " ", startingAt: 0)) | \(moveStr.padding(toLength: 9, withPad: " ", startingAt: 0)) | \(sgfCoord)")
				} else {
					Issue.record("Failed to parse move \(moveStr)")
					return
				}
			} else {
				Issue.record("Error generating move \(moveNum): \(response)")
				return
			}
		}
		print("\n=== Generating SGF ===")
		let sgf = SGFGenerator.generateSGF(
			moves: moves,
			blackPlayer: "KataGo (Black)",
			whitePlayer: "KataGo (White)",
			komi: 7.5
		)
		let fileManager = FileManager.default
		let buildOutputDir = ".build/test-output"
		try fileManager.createDirectory(atPath: buildOutputDir, withIntermediateDirectories: true, attributes: nil)
		let timestamp = Int(Date().timeIntervalSince1970)
		let filename = "\(buildOutputDir)/game_20k_\(timestamp).sgf"
		try SGFGenerator.saveSGF(sgf, to: filename)
		print("✓ SGF file saved: \(filename)")
		print("\nSGF Content:")
		print(sgf)
		#expect(sgf.hasPrefix("(;FF[4]GM[1]SZ[19]"))
		#expect(sgf.contains("PB[KataGo (Black)]"))
		#expect(sgf.contains("PW[KataGo (White)]"))
		#expect(sgf.contains("KM[7.5]"))
		#expect(sgf.hasSuffix(")"))
		print("\n✓ Game generation test (20k model) passed")
	}
	func parseGTPMove(_ moveStr: String) -> Point? {
		guard moveStr.count >= 2 else { return nil }
		let colChar = moveStr.first!
		let rowStr = String(moveStr.dropFirst())
		guard let row = Int(rowStr), row >= 1, row <= 19 else { return nil }
		var col: Int
		if colChar >= "A" && colChar <= "H" {
			col = Int(colChar.asciiValue! - 65)
		} else if colChar >= "J" && colChar <= "T" {
			col = Int(colChar.asciiValue! - 65) - 1
		} else {
			return nil
		}
		let y = 19 - row
		return Point(x: col, y: y)
	}
}

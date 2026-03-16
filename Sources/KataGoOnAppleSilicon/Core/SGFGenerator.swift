import Foundation
public struct SGFGenerator {
	public static func gtpToSgf(_ gtpCoord: String) -> String {
		guard gtpCoord.count >= 2 else { return "" }
		let colChar = gtpCoord.first!
		let rowStr = String(gtpCoord.dropFirst())
		guard let row = Int(rowStr), row >= 1, row <= 19 else { return "" }
		var col: Int
		if colChar >= "A" && colChar <= "H" {
			col = Int(colChar.asciiValue! - 65)
		} else if colChar >= "J" && colChar <= "T" {
			col = Int(colChar.asciiValue! - 65) - 1
		} else {
			return ""
		}
		let sgfRow = 19 - row
		let sgfChars = "abcdefghijklmnopqrs"
		let sgfColChar = sgfChars[sgfChars.index(sgfChars.startIndex, offsetBy: col)]
		let sgfRowChar = sgfChars[sgfChars.index(sgfChars.startIndex, offsetBy: sgfRow)]
		return "\(sgfColChar)\(sgfRowChar)"
	}
	public static func pointToSgf(_ point: Point) -> String {
		let sgfChars = "abcdefghijklmnopqrs"
		let sgfColChar = sgfChars[sgfChars.index(sgfChars.startIndex, offsetBy: point.x)]
		let sgfRowChar = sgfChars[sgfChars.index(sgfChars.startIndex, offsetBy: point.y)]
		return "\(sgfColChar)\(sgfRowChar)"
	}
	public static func generateSGF(
		moves: [(Stone, Point)],
		blackPlayer: String = "Black",
		whitePlayer: String = "White",
		komi: Float = 7.5,
		result: String? = nil
	) -> String {
		var sgf = "(;FF[4]GM[1]SZ[19]"
		sgf += "PB[\(blackPlayer)]"
		sgf += "PW[\(whitePlayer)]"
		sgf += "KM[\(komi)]"
		if let result {
			sgf += "RE[\(result)]"
		}
		for (stone, point) in moves {
			let sgfCoord = pointToSgf(point)
			let moveColor = stone == .black ? "B" : "W"
			sgf += ";\(moveColor)[\(sgfCoord)]"
		}
		sgf += ")"
		return sgf
	}
	public static func generateSGF(
		from board: Board,
		blackPlayer: String = "Black",
		whitePlayer: String = "White",
		komi: Float = 7.5,
		result: String? = nil
	) -> String {
		let moves = board.moveHistory.compactMap { move -> (Stone, Point)? in
			guard let location = move.location else { return nil }
			return (move.player, location)
		}
		return generateSGF(
			moves: moves,
			blackPlayer: blackPlayer,
			whitePlayer: whitePlayer,
			komi: komi,
			result: result
		)
	}
	public static func saveSGF(_ sgfContent: String, to filename: String) throws {
		let url = URL(fileURLWithPath: filename)
		try sgfContent.write(to: url, atomically: true, encoding: .utf8)
	}
}

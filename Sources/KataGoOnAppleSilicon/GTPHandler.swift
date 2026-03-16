import CoreML
import Foundation
public class GTPHandler {
	private let katago: KataGoInference
	private var board: Board = Board()
	private var profile: String = "AI"
	private var rules: Rules = .defaultRules
	public init(katago: KataGoInference) {
		self.katago = katago
	}
	public func setProfile(_ profile: String) {
		self.profile = profile
	}
	public func getProfile() -> String {
		profile
	}
	public func handleCommand(_ command: String) -> String {
		let parts = command.split(separator: " ").map { String($0) }
		guard !parts.isEmpty else { return "? \n\n" }
		let cmd = parts[0]
		switch cmd {
		case "protocol_version":
			return "= 2\n\n"
		case "name":
			return "= KataGoOnAppleSilicon\n\n"
		case "version":
			return "= 1.0\n\n"
		case "known_command":
			return parts.count > 1 && knownCommands.contains(parts[1]) ? "= true\n\n" : "= false\n\n"
		case "list_commands":
			return "= " + knownCommands.joined(separator: " ") + "\n\n"
		case "boardsize":
			return "= \n\n"
		case "clear_board":
			board = Board()
			return "= \n\n"
		case "komi":
			return "= \n\n"
		case "play":
			if parts.count >= 3 {
				let colorStr = parts[1]
				let moveStr = parts[2]
				let stone: Stone = colorStr == "black" ? .black : .white
				if let point = parseMove(moveStr) {
					if board.playMove(at: point, stone: stone) {
						return "= \n\n"
					}
					return "? illegal move\n\n"
				}
				return "? syntax error\n\n"
			}
			return "? syntax error\n\n"
		case "kata-set-rules":
			if parts.count < 2 {
				return "? Expected at least one argument for kata-set-rules\n\n"
			}
			let preset = parts[1...].joined(separator: " ").trimmingCharacters(in: .whitespaces).lowercased()
			if preset == "chinese" {
				rules = .chineseRules
				return "= \n\n"
			}
			return "? Unknown rules '\(preset)'\n\n"
		case "genmove":
			if parts.count >= 2 {
				let colorStr = parts[1]
				let stone: Stone = colorStr == "black" ? .black : .white
				do {
					let boardState = BoardState(board: board, rules: rules)
					let output = try katago.predict(board: boardState, profile: profile)
					let move = selectMove(from: output.policy, greedy: false)
					if let point = parseMove(move) {
						if board.playMove(at: point, stone: stone) {
							return "= \(move)\n\n"
						}
						return "? illegal move: \(move)\n\n"
					}
					return "? failed to parse generated move: \(move)\n\n"
				} catch {
					return "? \(error.localizedDescription)\n\n"
				}
			} else {
				return "? syntax error\n\n"
			}
		case "quit":
			return "= \n\n"
		default:
			return "? unknown command\n\n"
		}
	}
	private let knownCommands = ["protocol_version", "name", "version", "known_command", "list_commands", "boardsize", "clear_board", "komi", "play", "genmove", "kata-set-rules", "quit"]
	private func parseMove(_ move: String) -> Point? {
		guard move.count >= 2 else { return nil }
		let colChar = move.first!
		let rowStr = String(move.dropFirst())
		guard let row = Int(rowStr), row >= 1, row <= 19 else { return nil }
		var col: Int
		if colChar >= "A" && colChar <= "H" {
			col = Int(colChar.asciiValue! - 65)
		} else if colChar >= "J" && colChar <= "T" {
			col = Int(colChar.asciiValue! - 65) - 1
		} else {
			return nil
		}
		return Point(x: col, y: 19 - row)
	}
	private func selectMove(from policy: MLMultiArray, greedy: Bool = true) -> String {
		greedy ? selectMoveGreedy(from: policy) : selectMoveProbabilistic(from: policy)
	}
	private func selectMoveGreedy(from policy: MLMultiArray) -> String {
		var maxProb: Float = 0
		var maxY = 0
		var maxX = 0
		for y in 0..<19 {
			for x in 0..<19 {
				let prob = getPolicyProbability(policy: policy, x: x, y: y)
				if prob > maxProb {
					maxProb = prob
					maxY = y
					maxX = x
				}
			}
		}
		return coordinateToGTP(x: maxX, y: maxY)
	}
	private func selectMoveProbabilistic(from policy: MLMultiArray) -> String {
		let moves = collectMovesWithProbabilities(from: policy)
		guard !moves.isEmpty else {
			return selectMoveGreedy(from: policy)
		}
		let totalProb = moves.reduce(0.0) { $0 + $1.prob }
		guard totalProb > 0 else {
			return selectMoveGreedy(from: policy)
		}
		let normalizedMoves = moves.map { (x: $0.x, y: $0.y, prob: $0.prob / totalProb) }
		let random = Float.random(in: 0..<1)
		var cumulativeProb: Float = 0
		for move in normalizedMoves {
			cumulativeProb += move.prob
			if random <= cumulativeProb {
				return coordinateToGTP(x: move.x, y: move.y)
			}
		}
		let lastMove = normalizedMoves.last!
		return coordinateToGTP(x: lastMove.x, y: lastMove.y)
	}
	private func getPolicyProbability(policy: MLMultiArray, x: Int, y: Int) -> Float {
		let positionIndex = y * 19 + x
		return Float(policy[[0, 0, NSNumber(value: positionIndex)]].doubleValue)
	}
	private func collectMovesWithProbabilities(from policy: MLMultiArray) -> [(x: Int, y: Int, prob: Float)] {
		var moves: [(x: Int, y: Int, prob: Float)] = []
		for y in 0..<19 {
			for x in 0..<19 {
				let prob = getPolicyProbability(policy: policy, x: x, y: y)
				if prob > 0 {
					moves.append((x: x, y: y, prob: prob))
				}
			}
		}
		return moves
	}
	private func coordinateToGTP(x: Int, y: Int) -> String {
		let colLetter = x < 8 ? String(UnicodeScalar(65 + x)!) : String(UnicodeScalar(66 + x)!)
		let row = 19 - y
		return "\(colLetter)\(row)"
	}
}

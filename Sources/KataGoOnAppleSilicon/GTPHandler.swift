import CoreML
import Foundation
public class GTPHandler {
    private let katago: KataGoInference
    private var board: Board = Board()
    private var profile: String = "AI"
    private var rules: Rules = .defaultRules
    private var resignWinRateThreshold: Double = 0.10
    private var resignConsecutiveMoveThreshold: Int = 10
    private var consecutiveBehindCount: [Stone: Int] = [.black: 0, .white: 0]
    private var friendlyPassEnabled: Bool = false
    private var friendlyPassWinRateDelta: Double = 0.02
    private var friendlyPassLeadDelta: Double = 1.0
    private var lastPlayPassColor: Stone? = nil
    private var friendlyPassMinimumTurn: Int = 0

    public init(katago: KataGoInference) {
        self.katago = katago
    }

    /// Set the profile to use for inference (e.g., "AI", "20k", "9d", etc.)
    public func setProfile(_ profile: String) {
        self.profile = profile
    }

    /// Get the current profile being used for inference
    public func getProfile() -> String {
        return profile
    }

    /// Configure resign thresholds and reset the consecutive-behind counters for both colors.
    public func setResignThreshold(winRate: Double, consecutiveMoves: Int) {
        resignWinRateThreshold = winRate
        resignConsecutiveMoveThreshold = consecutiveMoves
        consecutiveBehindCount = [.black: 0, .white: 0]
    }

    /// Configure friendly pass behavior.
    public func setFriendlyPassOptions(
        enabled: Bool,
        winRateDelta: Double = 0.02,
        leadDelta: Double = 1.0,
        minimumTurn: Int = 0
    ) {
        friendlyPassEnabled = enabled
        friendlyPassWinRateDelta = winRateDelta
        friendlyPassLeadDelta = leadDelta
        friendlyPassMinimumTurn = minimumTurn
    }

    private func successResponse(_ value: String = "") -> String {
        return value.isEmpty ? "= \n\n" : "= \(value)\n\n"
    }

    private func errorResponse(_ message: String) -> String {
        return "? \(message)\n\n"
    }

    /// Process a GTP command and return response
    public func handleCommand(_ command: String) -> String {
        let parts = command.split(separator: " ").map { String($0) }
        guard !parts.isEmpty else { return errorResponse("") }

        let cmd = parts[0]
        switch cmd {
        case "protocol_version":   return successResponse("2")
        case "name":               return successResponse("KataGoOnAppleSilicon")
        case "version":            return successResponse("1.0")
        case "known_command":      return parts.count > 1 && knownCommands.contains(parts[1])
                                       ? successResponse("true") : successResponse("false")
        case "list_commands":      return successResponse(knownCommands.joined(separator: " "))
        case "boardsize":          return successResponse()
        case "clear_board":
            board = Board()
            consecutiveBehindCount = [.black: 0, .white: 0]
            lastPlayPassColor = nil
            return successResponse()
        case "komi":               return successResponse()
        case "play":               return handlePlay(parts: parts)
        case "kata-set-rules":     return handleKataSetRules(parts: parts)
        case "genmove":            return handleGenmove(parts: parts)
        case "showboard":          return handleShowboard()
        case "kata-rawnn":         return handleKataRawNN(parts: parts)
        case "final_score":        return handleFinalScore()
        case "quit":               return successResponse()
        default:                   return errorResponse("unknown command")
        }
    }

    private func handlePlay(parts: [String]) -> String {
        if parts.count >= 3 {
            let colorStr = parts[1]
            let moveStr = parts[2]
            let stone: Stone = colorStr == "black" ? .black : .white
            if moveStr.lowercased() == "pass" {
                _ = board.playPass(stone: stone)
                lastPlayPassColor = stone
                return successResponse()
            } else {
                lastPlayPassColor = nil
                if let point = parseMove(moveStr) {
                    if board.playMove(at: point, stone: stone) {
                        return successResponse()
                    } else {
                        return errorResponse("illegal move")
                    }
                } else {
                    return errorResponse("syntax error")
                }
            }
        } else {
            return errorResponse("syntax error")
        }
    }

    private func handleKataSetRules(parts: [String]) -> String {
        if parts.count < 2 {
            return errorResponse("Expected at least one argument for kata-set-rules")
        }
        let preset = parts[1...].joined(separator: " ").trimmingCharacters(in: .whitespaces).lowercased()
        if preset == "chinese" {
            rules = .chineseRules
            return successResponse()
        } else {
            return errorResponse("Unknown rules '\(preset)'")
        }
    }

    private func handleGenmove(parts: [String]) -> String {
        if parts.count >= 2 {
            let colorStr = parts[1]
            let stone: Stone = colorStr == "black" ? .black : .white
            do {
                let boardState = BoardState(board: board, nextPlayer: stone, rules: rules)
                let output = try katago.predict(board: boardState, profile: profile)

                // Resign logic
                let postOutput = output.postprocess(board: board, nextPlayer: stone)
                let currentPlayerWinRate = postOutput.whiteWinProb
                if currentPlayerWinRate < resignWinRateThreshold {
                    let count = consecutiveBehindCount[stone, default: 0] + 1
                    consecutiveBehindCount[stone] = count
                    if count >= resignConsecutiveMoveThreshold {
                        consecutiveBehindCount[stone] = 0
                        lastPlayPassColor = nil
                        return successResponse("resign")
                    }
                } else {
                    consecutiveBehindCount[stone] = 0
                }

                // Friendly pass: if opponent just passed and passing is safe, pass back
                if friendlyPassEnabled, let passColor = lastPlayPassColor, passColor != stone {
                    if let passResponse = try tryFriendlyPass(stone: stone, currentOutput: postOutput) {
                        return passResponse
                    }
                }

                let move = selectMove(from: postOutput.policyProbs, board: board, stone: stone)

                // Handle pass before attempting to parse as a board coordinate
                if move.lowercased() == "pass" {
                    _ = board.playPass(stone: stone)
                    lastPlayPassColor = stone
                    return successResponse("pass")
                }

                // Play the generated move on the board
                if let point = parseMove(move) {
                    if board.playMove(at: point, stone: stone) {
                        return successResponse(move)
                    } else {
                        return errorResponse("illegal move: \(move)")
                    }
                } else {
                    return errorResponse("failed to parse generated move: \(move)")
                }
            } catch {
                return errorResponse(error.localizedDescription)
            }
        } else {
            return errorResponse("syntax error")
        }
    }

    private func handleShowboard() -> String {
        var lines: [String] = []
        for y in 0..<19 {
            let rowNum = 19 - y
            let prefix = rowNum < 10 ? " \(rowNum)" : "\(rowNum)"
            let cells = (0..<19).map { x -> String in
                switch board.stones[y][x] {
                case .black: return "X"
                case .white: return "O"
                default:     return "."
                }
            }.joined(separator: " ")
            lines.append("\(prefix) \(cells)")
        }
        return successResponse(lines.joined(separator: "\n"))
    }

    private func handleKataRawNN(parts: [String]) -> String {
        let symmetry = Int(parts.count > 1 ? parts[1] : "0") ?? 0
        do {
            let nextPlayer: Stone = board.turnNumber % 2 == 0 ? .black : .white
            let boardState = BoardState(board: board, nextPlayer: nextPlayer, rules: rules)
            let result = try katago.rawNN(
                board: board, boardState: boardState,
                profile: profile, whichSymmetry: symmetry)
            return successResponse(result)
        } catch {
            return errorResponse(error.localizedDescription)
        }
    }

    private func handleFinalScore() -> String {
        do {
            let nextPlayer: Stone = board.turnNumber % 2 == 0 ? .black : .white
            let boardState = BoardState(board: board, nextPlayer: nextPlayer, rules: rules)
            let output = try katago.predict(board: boardState, profile: "AI")
            let postOutput = output.postprocess(board: board, nextPlayer: nextPlayer)
            let lead = postOutput.whiteLead
            let roundedLead = Foundation.round(lead + 0.5) - 0.5
            if roundedLead > 0 {
                return successResponse(String(format: "W+%.1f", roundedLead))
            } else if roundedLead < 0 {
                return successResponse(String(format: "B+%.1f", -roundedLead))
            } else {
                return successResponse("0")
            }
        } catch {
            return errorResponse(error.localizedDescription)
        }
    }

    private let knownCommands = ["protocol_version", "name", "version", "known_command", "list_commands", "boardsize", "clear_board", "komi", "play", "genmove", "kata-set-rules", "showboard", "kata-rawnn", "final_score", "quit"]

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

    private static let passPolicyIndex = 361

    private func selectMove(from policyProbs: [Float], board: Board, stone: Stone) -> String {
        let moves = collectMovesWithProbabilities(from: policyProbs, board: board, stone: stone)

        guard !moves.isEmpty else { return "pass" }

        let totalProb = moves.reduce(0.0) { $0 + $1.prob }
        guard totalProb > 0 else { return selectMoveGreedy(from: policyProbs) }

        let normalizedMoves = moves.map { (x: $0.x, y: $0.y, prob: $0.prob / totalProb) }
        let random = Float.random(in: 0..<1)
        var cumulativeProb: Float = 0

        for move in normalizedMoves {
            cumulativeProb += move.prob
            if random <= cumulativeProb {
                return moveToGTP(x: move.x, y: move.y)
            }
        }

        let lastMove = normalizedMoves.last!
        return moveToGTP(x: lastMove.x, y: lastMove.y)
    }

    private func selectMoveGreedy(from policyProbs: [Float]) -> String {
        var maxProb: Float = 0
        var maxIdx = -1

        for i in 0..<361 {
            let prob = policyProbs[i]
            if prob > maxProb {
                maxProb = prob
                maxIdx = i
            }
        }

        let passProb = policyProbs[GTPHandler.passPolicyIndex]
        if passProb > maxProb {
            return "pass"
        }

        if maxIdx == -1 { return "pass" }
        return coordinateToGTP(x: maxIdx % 19, y: maxIdx / 19)
    }

    private func moveToGTP(x: Int, y: Int) -> String {
        return x == -1 ? "pass" : coordinateToGTP(x: x, y: y)
    }

    private func collectMovesWithProbabilities(from policyProbs: [Float], board: Board, stone: Stone) -> [(x: Int, y: Int, prob: Float)] {
        var moves: [(x: Int, y: Int, prob: Float)] = []

        for y in 0..<19 {
            for x in 0..<19 {
                let prob = policyProbs[y * 19 + x]
                if prob > 0 {
                    let point = Point(x: x, y: y)
                    if board.isLegalMove(at: point, stone: stone) {
                        moves.append((x: x, y: y, prob: prob))
                    }
                }
            }
        }

        let passProb = policyProbs[GTPHandler.passPolicyIndex]
        if passProb > 0 {
            moves.append((x: -1, y: -1, prob: passProb))
        }
        return moves
    }

    private func coordinateToGTP(x: Int, y: Int) -> String {
        let colLetter = x < 8 ? String(UnicodeScalar(65 + x)!) : String(UnicodeScalar(66 + x)!)
        let row = 19 - y
        return "\(colLetter)\(row)"
    }

    /// Evaluate whether passing is safe after the opponent passed.
    private func tryFriendlyPass(
        stone: Stone,
        currentOutput: PostProcessedModelOutput
    ) throws -> String? {
        guard board.turnNumber >= friendlyPassMinimumTurn else { return nil }

        let currentWinRate = currentOutput.whiteWinProb
        let currentLead = currentOutput.whiteLead

        let postPassBoard = board.copy()
        _ = postPassBoard.playPass(stone: stone)

        let postPassBoardState = BoardState(board: postPassBoard, nextPlayer: stone.opponent, rules: rules)
        let postPassModelOutput = try katago.predict(board: postPassBoardState, profile: profile)

        lastPlayPassColor = nil

        let postPassOutput = postPassModelOutput.postprocess(
            board: postPassBoard,
            nextPlayer: stone.opponent
        )

        let postPassWinRate = postPassOutput.whiteLossProb
        let postPassLead = -postPassOutput.whiteLead

        let winRateDiff = abs(currentWinRate - postPassWinRate)
        let leadDiff = abs(currentLead - postPassLead)
        guard winRateDiff <= friendlyPassWinRateDelta && leadDiff <= friendlyPassLeadDelta else {
            return nil
        }

        _ = board.playPass(stone: stone)
        return successResponse("pass")
    }
}

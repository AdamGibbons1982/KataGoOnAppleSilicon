import CoreML
import Foundation

/// Handles GTP commands and responses
public class GTPHandler {
    private let katago: KataGoInference
    private var board: Board = Board()  // Placeholder board
    
    public init(katago: KataGoInference) {
        self.katago = katago
    }
    
    /// Process a GTP command and return response
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
            return "= \n\n"  // Assume 19x19
        case "clear_board":
            board = Board()
            return "= \n\n"
        case "komi":
            // Set komi, but placeholder
            return "= \n\n"
        case "play":
            if parts.count >= 3 {
                let colorStr = parts[1]
                let moveStr = parts[2]
                let stone: Stone = colorStr == "black" ? .black : .white
                if let point = parseMove(moveStr) {
                    if board.playMove(at: point, stone: stone) {
                        return "= \n\n"
                    } else {
                        return "? illegal move\n\n"
                    }
                } else {
                    return "? syntax error\n\n"
                }
            } else {
                return "? syntax error\n\n"
            }
        case "genmove":
            if parts.count >= 2 {
                let _ = parts[1]  // color, not used yet
                do {
                    let boardState = BoardState(board: board)  // Use actual board
                    let output = try katago.predict(board: boardState, profile: "AI")  // Default to AI
                    let move = selectMove(from: output.policy)
                    return "= \(move)\n\n"
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
    
    private let knownCommands = ["protocol_version", "name", "version", "known_command", "list_commands", "boardsize", "clear_board", "komi", "play", "genmove", "quit"]
    
    private func parseMove(_ move: String) -> Point? {
        guard move.count >= 2 else { return nil }
        let colChar = move.first!
        let rowStr = String(move.dropFirst())
        guard let row = Int(rowStr), row >= 1, row <= 19 else { return nil }
        
        var col: Int
        if colChar >= "A" && colChar <= "H" {
            col = Int(colChar.asciiValue! - 65)
        } else if colChar >= "J" && colChar <= "T" {
            col = Int(colChar.asciiValue! - 65) - 1  // Skip I
        } else {
            return nil
        }
        
        return Point(x: col, y: 19 - row)  // GTP is 1-based, top-left
    }
    
    private func selectMove(from policy: MLMultiArray) -> String {
        // Policy is [1, 19, 19], find max in [0,:,:]
        var maxProb: Float = 0
        var maxY = 0
        var maxX = 0
        for y in 0..<19 {
            for x in 0..<19 {
                let prob = Float(policy[[0, NSNumber(value: y), NSNumber(value: x), 0]].doubleValue)
                if prob > maxProb {
                    maxProb = prob
                    maxY = y
                    maxX = x
                }
            }
        }
        let colLetter = maxX < 8 ? String(UnicodeScalar(65 + maxX)!) : String(UnicodeScalar(66 + maxX)!)  // Skip I
        let row = 19 - maxY  // GTP: 19 at top
        return "\(colLetter)\(row)"
    }
}
import Foundation
import KataGoOnAppleSilicon

/// Game Generator: Creates a 10-move game for debugging purposes
/// Prints genmove responses and SGF coordinates side by side for verification
func main() {
    print("=== KataGo Game Generator ===")
    print("Generating a 10-move game for debugging...\n")

    do {
        // Initialize KataGo
        print("Initializing KataGo inference...")
        let katago = KataGoInference()

        print("Loading AI model...")
        try katago.loadModel(for: "AI")
        print("✓ AI model loaded\n")

        // Initialize GTP handler
        let gtp = GTPHandler(katago: katago)

        // Clear board
        _ = gtp.handleCommand("clear_board")

        // Track moves for SGF generation
        var moves: [(Stone, Point)] = []

        print("Move | Color | GTP Coord | SGF Coord")
        print("-----|-------|-----------|----------")

        // Generate 10 moves alternating between black and white
        for moveNum in 1...10 {
            let color = moveNum % 2 == 1 ? "black" : "white"
            let stone: Stone = color == "black" ? .black : .white

            // Generate move
            let response = gtp.handleCommand("genmove \(color)")

            // Parse response
            if response.starts(with: "=") {
                // Extract move from response (format: "= D4\n\n")
                let moveStr = response
                    .replacingOccurrences(of: "=", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Convert to SGF
                let sgfCoord = SGFGenerator.gtpToSgf(moveStr)

                // Parse move to get Point
                if let point = parseGTPMove(moveStr) {
                    moves.append((stone, point))

                    // Print move info
                    let colorStr = color == "black" ? "Black" : "White"
                    print(String(format: "%4d | %5s | %9s | %9s",
                                moveNum, colorStr, moveStr, sgfCoord))
                } else {
                    print("Error: Failed to parse move \(moveStr)")
                    break
                }
            } else {
                print("Error generating move \(moveNum): \(response)")
                break
            }
        }

        // Generate SGF
        print("\n=== Generating SGF ===")
        let sgf = SGFGenerator.generateSGF(
            moves: moves,
            blackPlayer: "KataGo (Black)",
            whitePlayer: "KataGo (White)",
            komi: 7.5
        )

        // Save SGF file with timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "game_\(timestamp).sgf"
        try SGFGenerator.saveSGF(sgf, to: filename)

        print("✓ SGF file saved: \(filename)")
        print("\nSGF Content:")
        print(sgf)

    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

/// Parse GTP move string to Point
/// - Parameter moveStr: GTP coordinate (e.g., "D4")
/// - Returns: Point if valid, nil otherwise
func parseGTPMove(_ moveStr: String) -> Point? {
    guard moveStr.count >= 2 else { return nil }

    let colChar = moveStr.first!
    let rowStr = String(moveStr.dropFirst())
    guard let row = Int(rowStr), row >= 1, row <= 19 else { return nil }

    var col: Int
    if colChar >= "A" && colChar <= "H" {
        col = Int(colChar.asciiValue! - 65)  // A=0, B=1, ..., H=7
    } else if colChar >= "J" && colChar <= "T" {
        col = Int(colChar.asciiValue! - 65) - 1  // J=8, K=9, ..., T=18 (skip I)
    } else {
        return nil
    }

    // GTP: 1 is top (y=18), 19 is bottom (y=0)
    let y = 19 - row

    return Point(x: col, y: y)
}

// Run the main function
main()

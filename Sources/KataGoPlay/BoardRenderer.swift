import Foundation
import KataGoOnAppleSilicon

enum ANSI {
    static let reset  = "\u{1B}[0m"
    static let bold   = "\u{1B}[1m"
    static let cyan   = "\u{1B}[36m"
    static let yellow = "\u{1B}[33m"
}

private let starPointSet: Set<String> = [
    "3,3", "15,3", "3,15", "15,15",
    "3,9", "15,9", "9,3", "9,15", "9,9"
]

private func isStarPoint(x: Int, y: Int) -> Bool {
    starPointSet.contains("\(x),\(y)")
}

/// Convert a GTP coordinate string (e.g. "D4") to internal (x, y).
/// Internal: x=0 left, y=0 top (GTP row 19).
func gtpToPoint(_ coord: String) -> Point? {
    let upper = coord.uppercased()
    guard !upper.isEmpty else { return nil }
    let col = upper.first!
    let rowStr = String(upper.dropFirst())
    guard let row = Int(rowStr), row >= 1, row <= 19 else { return nil }
    let x: Int
    if col >= "A" && col <= "H" {
        x = Int(col.asciiValue! - 65)
    } else if col >= "J" && col <= "T" {
        x = Int(col.asciiValue! - 65) - 1
    } else {
        return nil
    }
    return Point(x: x, y: 19 - row)
}

/// Convert internal (x, y) to GTP coordinate string.
func pointToGTP(x: Int, y: Int) -> String {
    let colScalar: UnicodeScalar = x < 8
        ? UnicodeScalar(65 + x)!
        : UnicodeScalar(66 + x)!   // skip I
    let col = Character(colScalar)
    let row = 19 - y
    return "\(col)\(row)"
}

/// Parse a showboard GTP response into a 19×19 grid of optional Stone values.
/// Grid indexing: grid[y][x], y=0 = top row (GTP row 19).
func parseShowboard(_ response: String) -> [[Stone?]] {
    var grid: [[Stone?]] = Array(
        repeating: Array(repeating: nil, count: 19),
        count: 19
    )

    var content = response
    if content.hasPrefix("= ") {
        content = String(content.dropFirst(2))
    }

    for line in content.components(separatedBy: "\n") {
        // Line format: "19 X O . ..." or " 1 X O . ..."
        // First 2 chars = row number (right-aligned), then space, then cells
        guard line.count > 3 else { continue }

        let prefix = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
        guard let rowNum = Int(prefix), rowNum >= 1, rowNum <= 19 else { continue }
        let y = 19 - rowNum

        let cellsPart = String(line.dropFirst(3))
        let cells = cellsPart.split(separator: " ", omittingEmptySubsequences: true)
        for (x, cell) in cells.enumerated() where x < 19 {
            switch cell {
            case "X": grid[y][x] = .black
            case "O": grid[y][x] = .white
            default:  grid[y][x] = nil
            }
        }
    }

    return grid
}

private let colHeaderLine = "   A B C D E F G H J K L M N O P Q R S T"

/// Render the board with optional last-move highlight and hint overlays.
func renderBoard(
    grid: [[Stone?]],
    lastMove: String? = nil,
    hints: [(coord: String, prob: Double)] = []
) {
    // Build hint rank map keyed by "x,y"
    var hintMap: [String: Int] = [:]
    for (i, hint) in hints.prefix(5).enumerated() {
        if let pt = gtpToPoint(hint.coord) {
            hintMap["\(pt.x),\(pt.y)"] = i + 1
        }
    }

    let lastMoveXY: (x: Int, y: Int)?
    if let lm = lastMove, lm.lowercased() != "pass", let pt = gtpToPoint(lm) {
        lastMoveXY = (x: pt.x, y: pt.y)
    } else {
        lastMoveXY = nil
    }

    print(colHeaderLine)

    for y in 0..<19 {
        let rowNum = 19 - y
        let prefix = rowNum < 10 ? " \(rowNum)" : "\(rowNum)"
        var cells: [String] = []

        for x in 0..<19 {
            let isLastMove = lastMoveXY.map { $0.x == x && $0.y == y } ?? false
            let key = "\(x),\(y)"

            let cell: String
            if let stone = grid[y][x] {
                let symbol = stone == .black ? "●" : "○"
                cell = isLastMove ? "\(ANSI.bold)\(symbol)\(ANSI.reset)" : symbol
            } else if let rank = hintMap[key] {
                cell = "\(ANSI.cyan)\(rank)\(ANSI.reset)"
            } else if isStarPoint(x: x, y: y) {
                cell = "+"
            } else {
                cell = "·"
            }
            cells.append(cell)
        }

        let rowStr = cells.joined(separator: " ")
        print("\(prefix) \(rowStr) \(prefix)")
    }

    print(colHeaderLine)
}

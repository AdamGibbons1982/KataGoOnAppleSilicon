import Foundation
import KataGoOnAppleSilicon

struct RawNNResult {
    var whiteWin: Double = 0
    var whiteLoss: Double = 0
    var whiteLead: Double = 0
    var shorttermScoreError: Double = 0
    var policyRows: [[Double]] = []
    var policyPass: Double = 0
    var ownershipRows: [[Double]] = []
}

/// Parse a kata-rawnn GTP response into a RawNNResult.
func parseRawNN(_ response: String) -> RawNNResult {
    var result = RawNNResult()

    var content = response
    if content.hasPrefix("= ") {
        content = String(content.dropFirst(2))
    }

    let lines = content.components(separatedBy: "\n")
    var i = 0
    var parsingSection: String? = nil

    while i < lines.count {
        let line = lines[i]

        if line == "policy" {
            parsingSection = "policy"
            i += 1
            continue
        }
        if line == "whiteOwnership" {
            parsingSection = "ownership"
            i += 1
            continue
        }

        if parsingSection == "policy" {
            if line.hasPrefix("policyPass ") {
                parsingSection = nil
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count >= 2, let val = Double(parts[1]) {
                    result.policyPass = val
                }
                i += 1
                continue
            }
            let values = line.split(separator: " ", omittingEmptySubsequences: true)
                .compactMap { s -> Double? in
                    if s == "NAN" { return -1.0 }
                    return Double(s)
                }
            if values.count == 19 {
                result.policyRows.append(values)
            }
            i += 1
            continue
        }

        if parsingSection == "ownership" {
            let values = line.split(separator: " ", omittingEmptySubsequences: true)
                .compactMap { s -> Double? in
                    if s == "NAN" { return 0.0 }
                    return Double(s)
                }
            if values.count == 19 {
                result.ownershipRows.append(values)
            }
            i += 1
            continue
        }

        // Parse scalar key-value pairs
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        if parts.count >= 2, let val = Double(parts[1]) {
            switch parts[0] {
            case "whiteWin":            result.whiteWin = val
            case "whiteLoss":           result.whiteLoss = val
            case "whiteLead":           result.whiteLead = val
            case "shorttermScoreError": result.shorttermScoreError = val
            default: break
            }
        }

        i += 1
    }

    return result
}

/// Return the top-N moves by policy probability, sorted descending.
func topMoves(_ result: RawNNResult, count: Int = 5) -> [(coord: String, prob: Double)] {
    var indexed: [(index: Int, prob: Double)] = []

    for (rowIdx, row) in result.policyRows.enumerated() {
        for (colIdx, prob) in row.enumerated() {
            if prob >= 0 {
                indexed.append((index: rowIdx * 19 + colIdx, prob: prob))
            }
        }
    }
    if result.policyPass >= 0 {
        indexed.append((index: 361, prob: result.policyPass))
    }

    return indexed
        .sorted { $0.prob > $1.prob }
        .prefix(count)
        .map { item in
            let coord: String
            if item.index == 361 {
                coord = "pass"
            } else {
                let x = item.index % 19
                let y = item.index / 19
                coord = pointToGTP(x: x, y: y)
            }
            return (coord: coord, prob: item.prob)
        }
}

/// Print win-rate bar, score lead, and top-5 moves.
func printSummary(
    _ result: RawNNResult,
    currentPlayerName: String,
    opponentName: String
) {
    let currentWin = result.whiteWin
    let opponentWin = result.whiteLoss

    let barWidth = 30
    let filledCount = max(0, min(barWidth, Int(currentWin * Double(barWidth))))
    let filled = String(repeating: "█", count: filledCount)
    let empty  = String(repeating: "░", count: barWidth - filledCount)
    let curPct = Int((currentWin * 100).rounded())
    let oppPct = Int((opponentWin * 100).rounded())
    print("[\(filled)\(empty)] \(currentPlayerName) \(curPct)% | \(opponentName) \(oppPct)%")

    let lead = result.whiteLead
    let err  = result.shorttermScoreError
    let leader = lead >= 0 ? currentPlayerName : opponentName
    let absLead = abs(lead)
    print(String(format: "Score Lead: \(leader)+%.1f ±%.1f", absLead, err))

    let moves = topMoves(result)
    let moveStrs = moves.enumerated().map { i, m in
        String(format: "%d. %@ (%.1f%%)", i + 1, m.coord, m.prob * 100)
    }.joined(separator: "  ")
    print("Top moves: \(moveStrs)")
}

/// Print full analysis: summary + ownership heat map.
func printDetailedAnalysis(
    _ result: RawNNResult,
    currentPlayerName: String,
    opponentName: String
) {
    printSummary(result, currentPlayerName: currentPlayerName, opponentName: opponentName)

    guard !result.ownershipRows.isEmpty else { return }

    print("Ownership (█▓▒░ = \(currentPlayerName) territory, \(ANSI.cyan)░▒▓█\(ANSI.reset) = \(opponentName) territory):")
    let header = "   A B C D E F G H J K L M N O P Q R S T"
    print(header)

    for (yi, row) in result.ownershipRows.enumerated() {
        let rowNum = 19 - yi
        let prefix = rowNum < 10 ? " \(rowNum)" : "\(rowNum)"
        let cells = row.map { val -> String in
            let absVal = abs(val)
            if val >= 0 {
                if absVal > 0.75 { return "█" }
                if absVal > 0.50 { return "▓" }
                if absVal > 0.25 { return "▒" }
                if absVal > 0.05 { return "░" }
                return "·"
            } else {
                if absVal > 0.75 { return "\(ANSI.cyan)█\(ANSI.reset)" }
                if absVal > 0.50 { return "\(ANSI.cyan)▓\(ANSI.reset)" }
                if absVal > 0.25 { return "\(ANSI.cyan)▒\(ANSI.reset)" }
                if absVal > 0.05 { return "\(ANSI.cyan)░\(ANSI.reset)" }
                return "·"
            }
        }.joined(separator: " ")
        print("\(prefix) \(cells)")
    }

    print(header)
}

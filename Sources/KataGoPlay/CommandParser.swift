import Foundation

enum UserCommand {
    case move(String)
    case pass
    case hint
    case aiMove
    case analysis
    case save
    case board
    case profile(String)
    case quit
    case unknown(String)
}

struct CommandParser {
    static func parse(_ raw: String) -> UserCommand {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()

        if lower == "quit" || lower == "exit" || lower == "q" { return .quit }
        if lower == "pass" { return .pass }
        if lower == "hint" { return .hint }
        if lower == "ai" || lower == "aimove" { return .aiMove }
        if lower == "analysis" || lower == "analyze" { return .analysis }
        if lower == "save" { return .save }
        if lower == "board" || lower == "show" { return .board }

        if lower.hasPrefix("profile ") {
            let name = String(trimmed.dropFirst("profile ".count))
                .trimmingCharacters(in: .whitespaces)
            return .profile(name)
        }

        let upper = trimmed.uppercased()
        if isValidGTPCoord(upper) { return .move(upper) }

        return .unknown(raw)
    }

    static func isValidGTPCoord(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        let col = s.first!
        let rowStr = String(s.dropFirst())
        guard let row = Int(rowStr), row >= 1, row <= 19 else { return false }
        return (col >= "A" && col <= "H") || (col >= "J" && col <= "T")
    }
}

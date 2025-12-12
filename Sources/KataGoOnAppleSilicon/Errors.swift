import Foundation

/// Custom errors for the KataGo library
public enum KataGoError: Error, CustomStringConvertible {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case invalidInput(String)
    case inferenceFailed(String)
    case unsupportedProfile(String)
    
    public var description: String {
        switch self {
        case .modelNotFound(let name):
            return "Model not found: \(name)"
        case .modelLoadFailed(let reason):
            return "Model load failed: \(reason)"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .inferenceFailed(let reason):
            return "Inference failed: \(reason)"
        case .unsupportedProfile(let profile):
            return "Unsupported profile: \(profile)"
        }
    }
}
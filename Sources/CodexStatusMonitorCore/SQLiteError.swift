import Foundation

public enum SQLiteError: Error, LocalizedError, Equatable {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case missingColumn(String)

    public var errorDescription: String? {
        switch self {
        case let .openFailed(message):
            return "Could not open Codex database: \(message)"
        case let .prepareFailed(message):
            return "Could not prepare Codex query: \(message)"
        case let .stepFailed(message):
            return "Could not read Codex query result: \(message)"
        case let .missingColumn(name):
            return "Codex database query did not include \(name)."
        }
    }
}

import Foundation

public enum ProviderKind: String, CaseIterable, Equatable, Sendable {
    case codex
    case claude

    public var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        }
    }
}

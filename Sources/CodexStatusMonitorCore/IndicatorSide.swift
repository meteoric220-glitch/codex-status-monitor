import Foundation

public enum IndicatorSide: String, CaseIterable, Equatable, Sendable {
    case left
    case right

    public var displayName: String {
        switch self {
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }
}

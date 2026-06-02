import Foundation

public enum SessionEvent: Equatable, Sendable {
    case taskStarted(turnID: String?, timestamp: Date)
    case taskComplete(turnID: String?, timestamp: Date)
    case functionCall(name: String, callID: String?, arguments: String?, timestamp: Date)
    case functionCallOutput(callID: String?, timestamp: Date)
    case assistantMessage(text: String, phase: String?, timestamp: Date)
    case other(timestamp: Date)

    public var timestamp: Date {
        switch self {
        case let .taskStarted(_, timestamp),
             let .taskComplete(_, timestamp),
             let .functionCall(_, _, _, timestamp),
             let .functionCallOutput(_, timestamp),
             let .assistantMessage(_, _, timestamp),
             let .other(timestamp):
            return timestamp
        }
    }
}

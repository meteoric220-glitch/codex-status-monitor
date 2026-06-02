import Foundation

public enum MonitorStatus: String, Equatable, Sendable {
    case setup
    case error
    case done
    case waiting
    case working

    public var displayText: String {
        switch self {
        case .setup:
            return "Setup"
        case .error:
            return "Error"
        case .done:
            return "Done"
        case .waiting:
            return "Waiting"
        case .working:
            return "Working"
        }
    }
}

public struct MonitorSnapshot: Equatable, Sendable {
    public let status: MonitorStatus
    public let detail: String
    public let projectName: String?
    public let threadID: String?
    public let updatedAt: Date

    public init(
        status: MonitorStatus,
        detail: String,
        projectName: String? = nil,
        threadID: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.status = status
        self.detail = detail
        self.projectName = projectName
        self.threadID = threadID
        self.updatedAt = updatedAt
    }
}

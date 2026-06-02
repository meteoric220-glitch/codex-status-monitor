import Foundation

public struct CodexThread: Equatable, Sendable {
    public let id: String
    public let rolloutPath: URL
    public let cwd: URL
    public let updatedAtMilliseconds: Int64

    public init(id: String, rolloutPath: URL, cwd: URL, updatedAtMilliseconds: Int64) {
        self.id = id
        self.rolloutPath = rolloutPath
        self.cwd = cwd
        self.updatedAtMilliseconds = updatedAtMilliseconds
    }
}

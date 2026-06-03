import Foundation

public struct ClaudeSession: Equatable, Sendable {
    public let id: String
    public let transcriptPath: URL
    public let cwd: URL
    public let updatedAt: Date

    public init(id: String, transcriptPath: URL, cwd: URL, updatedAt: Date) {
        self.id = id
        self.transcriptPath = transcriptPath
        self.cwd = cwd
        self.updatedAt = updatedAt
    }
}

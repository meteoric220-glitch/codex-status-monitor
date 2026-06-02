import Foundation

public struct CodexPaths: Sendable {
    public let codexHome: URL

    public init(codexHome: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")) {
        self.codexHome = codexHome
    }

    public var stateDatabase: URL {
        codexHome.appending(path: "state_5.sqlite")
    }
}

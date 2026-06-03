import Foundation

public protocol ClaudeSessionResolving {
    func resolveSession(for projectDirectory: URL) throws -> ClaudeSession?
}

public final class ClaudeSessionResolver: ClaudeSessionResolving {
    private let projectsDirectory: URL
    private let parser: ClaudeSessionEventParser
    private let fileManager: FileManager

    public init(
        paths: ClaudePaths = ClaudePaths(),
        parser: ClaudeSessionEventParser = ClaudeSessionEventParser(),
        fileManager: FileManager = .default
    ) {
        self.projectsDirectory = paths.projectsDirectory
        self.parser = parser
        self.fileManager = fileManager
    }

    public init(
        projectsDirectory: URL,
        parser: ClaudeSessionEventParser = ClaudeSessionEventParser(),
        fileManager: FileManager = .default
    ) {
        self.projectsDirectory = projectsDirectory
        self.parser = parser
        self.fileManager = fileManager
    }

    public func resolveSession(for projectDirectory: URL) throws -> ClaudeSession? {
        guard fileManager.fileExists(atPath: projectsDirectory.path) else {
            return nil
        }

        let normalizedProjectPath = projectDirectory.standardizedFileURL.path
        let transcriptURLs = try transcriptURLs(in: projectsDirectory)
        var bestSession: ClaudeSession?

        for transcriptURL in transcriptURLs {
            guard let metadata = try parser.metadata(from: transcriptURL),
                  metadata.cwd.path == normalizedProjectPath
            else {
                continue
            }

            let fallbackUpdatedAt = fileModificationDate(for: transcriptURL) ?? metadata.updatedAt
            let updatedAt = max(metadata.updatedAt, fallbackUpdatedAt)
            let session = ClaudeSession(
                id: metadata.sessionID,
                transcriptPath: transcriptURL,
                cwd: metadata.cwd,
                updatedAt: updatedAt
            )

            if let current = bestSession, current.updatedAt >= session.updatedAt {
                continue
            }
            bestSession = session
        }

        return bestSession
    }

    private func transcriptURLs(in directory: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            if url.pathComponents.contains("subagents") {
                enumerator.skipDescendants()
                continue
            }

            guard url.pathExtension == "jsonl" else {
                continue
            }

            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues?.isRegularFile == true {
                urls.append(url)
            }
        }
        return urls
    }

    private func fileModificationDate(for url: URL) -> Date? {
        (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }
}

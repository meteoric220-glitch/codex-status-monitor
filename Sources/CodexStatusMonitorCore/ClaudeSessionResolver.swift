import Foundation

public protocol ClaudeSessionResolving {
    func resolveSession(for projectDirectory: URL) throws -> ClaudeSession?
}

public final class ClaudeSessionResolver: ClaudeSessionResolving {
    private let projectsDirectory: URL
    private let parser: ClaudeSessionEventParser
    private let fileManager: FileManager
    private let maxTranscriptCandidates: Int
    private var cache: [String: CacheEntry] = [:]

    public init(
        paths: ClaudePaths = ClaudePaths(),
        parser: ClaudeSessionEventParser = ClaudeSessionEventParser(),
        fileManager: FileManager = .default,
        maxTranscriptCandidates: Int = 100
    ) {
        self.projectsDirectory = paths.projectsDirectory
        self.parser = parser
        self.fileManager = fileManager
        self.maxTranscriptCandidates = maxTranscriptCandidates
    }

    public init(
        projectsDirectory: URL,
        parser: ClaudeSessionEventParser = ClaudeSessionEventParser(),
        fileManager: FileManager = .default,
        maxTranscriptCandidates: Int = 100
    ) {
        self.projectsDirectory = projectsDirectory
        self.parser = parser
        self.fileManager = fileManager
        self.maxTranscriptCandidates = maxTranscriptCandidates
    }

    public func resolveSession(for projectDirectory: URL) throws -> ClaudeSession? {
        guard fileManager.fileExists(atPath: projectsDirectory.path) else {
            return nil
        }

        let normalizedProjectPath = projectDirectory.standardizedFileURL.path
        let transcriptFiles = try transcriptFiles(in: projectsDirectory)
        let signature = DirectorySignature(files: transcriptFiles)

        if let cached = cache[normalizedProjectPath],
           cached.signature == signature {
            return cached.session
        }

        let candidateFiles = transcriptFiles.prefix(maxTranscriptCandidates)
        var bestSession: ClaudeSession?

        for transcriptFile in candidateFiles {
            guard let metadata = try parser.metadata(from: transcriptFile.url),
                  metadata.cwd.path == normalizedProjectPath
            else {
                continue
            }

            let updatedAt = max(metadata.updatedAt, transcriptFile.modifiedAt)
            let session = ClaudeSession(
                id: metadata.sessionID,
                transcriptPath: transcriptFile.url,
                cwd: metadata.cwd,
                updatedAt: updatedAt
            )

            if let current = bestSession, current.updatedAt >= session.updatedAt {
                continue
            }
            bestSession = session
        }

        cache[normalizedProjectPath] = CacheEntry(signature: signature, session: bestSession)
        return bestSession
    }

    private func transcriptFiles(in directory: URL) throws -> [TranscriptFile] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [TranscriptFile] = []
        for case let url as URL in enumerator {
            if url.pathComponents.contains("subagents") {
                enumerator.skipDescendants()
                continue
            }

            guard url.pathExtension == "jsonl" else {
                continue
            }

            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
            if resourceValues?.isRegularFile == true {
                files.append(TranscriptFile(
                    url: url,
                    modifiedAt: resourceValues?.contentModificationDate ?? .distantPast
                ))
            }
        }
        return files.sorted { lhs, rhs in
            if lhs.modifiedAt == rhs.modifiedAt {
                return lhs.url.path < rhs.url.path
            }
            return lhs.modifiedAt > rhs.modifiedAt
        }
    }
}

private struct TranscriptFile {
    let url: URL
    let modifiedAt: Date
}

private struct DirectorySignature: Equatable {
    let count: Int
    let newestModifiedAt: Date?

    init(files: [TranscriptFile]) {
        self.count = files.count
        self.newestModifiedAt = files.first?.modifiedAt
    }
}

private struct CacheEntry {
    let signature: DirectorySignature
    let session: ClaudeSession?
}

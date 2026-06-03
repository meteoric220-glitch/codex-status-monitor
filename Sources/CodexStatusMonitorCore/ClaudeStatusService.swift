import Foundation

public final class ClaudeStatusService: CodexStatusServicing {
    private let resolver: ClaudeSessionResolving
    private let parser: SessionEventParsing
    private let classifier: StateClassifier

    public init(
        resolver: ClaudeSessionResolving = ClaudeSessionResolver(),
        parser: SessionEventParsing = ClaudeSessionEventParser(),
        classifier: StateClassifier = StateClassifier()
    ) {
        self.resolver = resolver
        self.parser = parser
        self.classifier = classifier
    }

    public func snapshot(for projectDirectory: URL?) -> MonitorSnapshot {
        guard let projectDirectory else {
            return MonitorSnapshot(status: .setup, detail: "Choose Project")
        }

        let projectName = projectDirectory.lastPathComponent

        do {
            guard let session = try resolver.resolveSession(for: projectDirectory) else {
                return MonitorSnapshot(
                    status: .error,
                    detail: "No Data Yet",
                    projectName: projectName
                )
            }

            guard FileManager.default.fileExists(atPath: session.transcriptPath.path) else {
                return MonitorSnapshot(
                    status: .error,
                    detail: "Missing Session",
                    projectName: projectName,
                    threadID: session.id
                )
            }

            let events = try parser.parseEvents(from: session.transcriptPath)
            let status = classifier.classify(events: events)

            return MonitorSnapshot(
                status: status,
                detail: status.displayText,
                projectName: projectName,
                threadID: session.id
            )
        } catch {
            return MonitorSnapshot(
                status: .error,
                detail: "Error",
                projectName: projectName
            )
        }
    }
}

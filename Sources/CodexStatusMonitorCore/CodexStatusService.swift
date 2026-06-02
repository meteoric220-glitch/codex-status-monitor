import Foundation

public protocol CodexStatusServicing {
    func snapshot(for projectDirectory: URL?) -> MonitorSnapshot
}

public final class CodexStatusService: CodexStatusServicing {
    private let resolver: CodexThreadResolving
    private let parser: SessionEventParsing
    private let classifier: StateClassifier

    public init(
        resolver: CodexThreadResolving = CodexThreadResolver(),
        parser: SessionEventParsing = SessionEventParser(),
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
            guard let thread = try resolver.resolveThread(for: projectDirectory) else {
                return MonitorSnapshot(
                    status: .error,
                    detail: "No Thread",
                    projectName: projectName
                )
            }

            guard FileManager.default.fileExists(atPath: thread.rolloutPath.path) else {
                return MonitorSnapshot(
                    status: .error,
                    detail: "Missing Session",
                    projectName: projectName,
                    threadID: thread.id
                )
            }

            let events = try parser.parseEvents(from: thread.rolloutPath)
            let status = classifier.classify(events: events)

            return MonitorSnapshot(
                status: status,
                detail: status.displayText,
                projectName: projectName,
                threadID: thread.id
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

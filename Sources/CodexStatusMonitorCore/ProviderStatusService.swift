import Foundation

public final class ProviderStatusService: CodexStatusServicing {
    private let store: ProjectSelectionStore
    private let codexService: CodexStatusServicing
    private let claudeService: CodexStatusServicing

    public init(
        store: ProjectSelectionStore,
        codexService: CodexStatusServicing = CodexStatusService(),
        claudeService: CodexStatusServicing = ClaudeStatusService()
    ) {
        self.store = store
        self.codexService = codexService
        self.claudeService = claudeService
    }

    public func snapshot(for projectDirectory: URL?) -> MonitorSnapshot {
        switch store.selectedProvider {
        case .codex:
            return codexService.snapshot(for: projectDirectory)
        case .claude:
            return claudeService.snapshot(for: projectDirectory)
        }
    }
}

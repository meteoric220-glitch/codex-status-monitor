import CodexStatusMonitorCore
import Combine
import Foundation
import SwiftUI

@MainActor
final class StatusModel: ObservableObject {
    @Published private(set) var snapshot: MonitorSnapshot
    @Published var isExpanded = false

    private let store: ProjectSelectionStore
    private let service: CodexStatusServicing
    private var timer: Timer?
    private var collapseTask: Task<Void, Never>?
    private var lastStatus: MonitorStatus?

    init(store: ProjectSelectionStore, service: CodexStatusServicing) {
        self.store = store
        self.service = service
        self.snapshot = service.snapshot(for: store.selectedProjectDirectory)
        self.lastStatus = snapshot.status
    }

    func start() {
        refresh(expandOnChange: false)
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh(expandOnChange: Bool = true) {
        let nextSnapshot = service.snapshot(for: store.selectedProjectDirectory)
        let statusChanged = nextSnapshot.status != lastStatus
        snapshot = nextSnapshot

        if statusChanged || nextSnapshot.status == .setup {
            lastStatus = nextSnapshot.status
            if expandOnChange {
                expandTemporarily()
            }
        }
    }

    func expandTemporarily() {
        collapseTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isExpanded = true
        }

        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                guard let self, !Task.isCancelled else {
                    return
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    self.isExpanded = false
                }
            }
        }
    }
}

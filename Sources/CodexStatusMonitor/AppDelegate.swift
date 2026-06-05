import AppKit
import CodexStatusMonitorCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ProjectSelectionStore()
    private let recentAIApplicationTracker = RecentAIApplicationTracker()
    private lazy var service = ProviderStatusService(store: store)
    private var statusModel: StatusModel?
    private var capsuleController: CapsuleWindowController?
    private var statusMenu: NSMenu?
    private var statusMenuItem: NSMenuItem?
    private var projectMenuItem: NSMenuItem?
    private var revealProjectMenuItem: NSMenuItem?
    private var providerMenuItems: [ProviderKind: NSMenuItem] = [:]
    private var positionMenuItems: [IndicatorSide: NSMenuItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = StatusModel(store: store, service: service)
        self.statusModel = model

        let controller = CapsuleWindowController(model: model)
        self.capsuleController = controller
        controller.show()
        controller.onDoubleClick = { [weak self] in
            self?.activateRecentAIApplication()
        }

        recentAIApplicationTracker.start(provider: { [weak store] in
            store?.selectedProvider ?? .codex
        })

        installMenu(model: model)

        if store.selectedProjectDirectory == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.chooseProject()
            }
        }

        model.start()
    }

    private func installMenu(model: StatusModel) {
        let menu = NSMenu()
        menu.delegate = self

        let statusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        statusMenuItem = statusItem

        let projectItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        projectItem.isEnabled = false
        menu.addItem(projectItem)
        projectMenuItem = projectItem

        menu.addItem(.separator())
        menu.addItem(menuItem(
            title: "Refresh Now",
            action: #selector(refreshNow),
            keyEquivalent: "r",
            symbolName: "arrow.clockwise"
        ))
        menu.addItem(menuItem(
            title: "Change Project...",
            action: #selector(changeProject),
            keyEquivalent: ",",
            symbolName: "folder.badge.gearshape"
        ))
        let revealProjectItem = menuItem(
            title: "Reveal Project in Finder",
            action: #selector(revealProject),
            keyEquivalent: "",
            symbolName: "folder"
        )
        menu.addItem(revealProjectItem)
        revealProjectMenuItem = revealProjectItem

        menu.addItem(.separator())
        let providerMenu = NSMenu(title: "Provider")
        for provider in ProviderKind.allCases {
            let item = NSMenuItem(
                title: provider.displayName,
                action: #selector(selectProvider(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = provider.rawValue
            providerMenu.addItem(item)
            providerMenuItems[provider] = item
        }

        let providerItem = menuItem(
            title: "Provider",
            action: nil,
            keyEquivalent: "",
            symbolName: "cpu"
        )
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)

        let positionMenu = NSMenu(title: "Position")
        for side in IndicatorSide.allCases {
            let item = menuItem(
                title: side.displayName,
                action: #selector(selectPosition(_:)),
                keyEquivalent: "",
                symbolName: side.menuSymbolName
            )
            item.representedObject = side.rawValue
            positionMenu.addItem(item)
            positionMenuItems[side] = item
        }
        let positionItem = menuItem(
            title: "Position",
            action: nil,
            keyEquivalent: "",
            symbolName: "arrow.left.and.right"
        )
        positionItem.submenu = positionMenu
        menu.addItem(positionItem)

        menu.addItem(.separator())
        menu.addItem(menuItem(
            title: "Quit Codex Status Monitor",
            action: #selector(quit),
            keyEquivalent: "q",
            symbolName: "power"
        ))
        self.statusMenu = menu
        capsuleController?.contextMenu = menu
        refreshMenuState()
    }

    @objc private func selectProvider(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let provider = ProviderKind(rawValue: rawValue)
        else {
            return
        }

        statusModel?.selectProvider(provider)
        refreshMenuState()
    }

    @objc private func selectPosition(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let side = IndicatorSide(rawValue: rawValue)
        else {
            return
        }

        statusModel?.selectIndicatorSide(side)
        capsuleController?.positionWindow()
        refreshMenuState()
    }

    @objc private func refreshNow() {
        statusModel?.refresh(expandOnChange: false)
        refreshMenuState()
    }

    private func activateRecentAIApplication() {
        if recentAIApplicationTracker.activateRecentApplication(for: store.selectedProvider) == false {
            statusModel?.expandTemporarily()
        }
    }

    @objc private func changeProject() {
        chooseProject()
    }

    @objc private func revealProject() {
        guard let selectedProjectDirectory = store.selectedProjectDirectory else {
            chooseProject()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([selectedProjectDirectory])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func chooseProject() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Choose Codex Project"
        panel.prompt = "Monitor"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            store.selectedProjectDirectory = url.standardizedFileURL
            statusModel?.refresh()
            refreshMenuState()
        }
    }

    private func refreshMenuState() {
        refreshStatusMenuItem()
        refreshProjectMenuItem()
        refreshProviderMenuState()
        refreshPositionMenuState()
    }

    private func refreshStatusMenuItem() {
        let provider = store.selectedProvider
        let status = statusModel?.snapshot.status ?? .setup
        statusMenuItem?.title = "\(provider.displayName) · \(status.displayText)"
        statusMenuItem?.image = status.menuImage
    }

    private func refreshProjectMenuItem() {
        let projectName = store.selectedProjectDirectory?.lastPathComponent
        projectMenuItem?.title = projectName.map { "Project · \($0)" } ?? "No Project Selected"
        projectMenuItem?.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Project")
        revealProjectMenuItem?.isEnabled = store.selectedProjectDirectory != nil
    }

    private func refreshProviderMenuState() {
        let selectedProvider = store.selectedProvider
        for (provider, item) in providerMenuItems {
            item.state = provider == selectedProvider ? .on : .off
        }
    }

    private func refreshPositionMenuState() {
        let selectedSide = store.indicatorSide
        for (side, item) in positionMenuItems {
            item.state = side == selectedSide ? .on : .off
        }
    }

    private func menuItem(
        title: String,
        action: Selector?,
        keyEquivalent: String,
        symbolName: String
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = action == nil ? nil : self
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        return item
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuState()
    }
}

private extension IndicatorSide {
    var menuSymbolName: String {
        switch self {
        case .left:
            return "arrow.left"
        case .right:
            return "arrow.right"
        }
    }
}

private extension MonitorStatus {
    var menuImage: NSImage? {
        let symbolName: String
        switch self {
        case .setup:
            symbolName = "gearshape"
        case .error:
            symbolName = "exclamationmark.triangle"
        case .done:
            symbolName = "checkmark.circle"
        case .waiting:
            symbolName = "questionmark.circle"
        case .working:
            symbolName = "arrow.triangle.2.circlepath"
        }

        return NSImage(systemSymbolName: symbolName, accessibilityDescription: displayText)
    }
}

@MainActor
private final class RecentAIApplicationTracker {
    private var observer: NSObjectProtocol?
    private var recentByProvider: [ProviderKind: TrackedApplication] = [:]
    private var recentAny: TrackedApplication?
    private var provider: (() -> ProviderKind)?

    func start(provider: @escaping () -> ProviderKind) {
        self.provider = provider
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                self?.recordActivatedApplication(app)
            }
        }
    }

    func activateRecentApplication(for provider: ProviderKind) -> Bool {
        guard let candidate = recentByProvider[provider] ?? recentAny,
              let app = runningApplication(for: candidate)
        else {
            return false
        }

        return app.activate(options: [.activateAllWindows])
    }

    private func recordActivatedApplication(_ app: NSRunningApplication) {
        guard let trackedApplication = trackedApplication(for: app),
              app.processIdentifier != NSRunningApplication.current.processIdentifier
        else {
            return
        }

        let currentProvider = provider?() ?? .codex
        recentByProvider[currentProvider] = trackedApplication
        recentAny = trackedApplication
    }

    private func runningApplication(for trackedApplication: TrackedApplication) -> NSRunningApplication? {
        if let bundleIdentifier = trackedApplication.bundleIdentifier {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            if let app = apps.first {
                return app
            }
        }

        return NSWorkspace.shared.runningApplications.first { app in
            app.processIdentifier == trackedApplication.processIdentifier
                || normalizedName(app.localizedName) == trackedApplication.normalizedName
        }
    }

    private func trackedApplication(for app: NSRunningApplication) -> TrackedApplication? {
        let bundleIdentifier = app.bundleIdentifier
        let name = app.localizedName

        guard isAllowed(bundleIdentifier: bundleIdentifier, name: name) else {
            return nil
        }

        return TrackedApplication(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: app.processIdentifier,
            normalizedName: normalizedName(name)
        )
    }

    private func isAllowed(bundleIdentifier: String?, name: String?) -> Bool {
        if let bundleIdentifier, allowedBundleIdentifiers.contains(bundleIdentifier) {
            return true
        }

        guard let normalizedName = normalizedName(name) else {
            return false
        }

        return allowedNames.contains(normalizedName)
    }

    private func normalizedName(_ name: String?) -> String? {
        name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private let allowedBundleIdentifiers: Set<String> = [
        "com.openai.chat",
        "com.anthropic.claudefordesktop",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable"
    ]

    private let allowedNames: Set<String> = [
        "codex",
        "claude",
        "visual studio code",
        "code",
        "cursor",
        "terminal",
        "iterm2",
        "warp"
    ]
}

private struct TrackedApplication {
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let normalizedName: String?
}

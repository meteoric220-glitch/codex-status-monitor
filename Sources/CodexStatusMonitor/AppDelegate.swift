import AppKit
import CodexStatusMonitorCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ProjectSelectionStore()
    private lazy var service = ProviderStatusService(store: store)
    private var statusModel: StatusModel?
    private var capsuleController: CapsuleWindowController?
    private var statusMenu: NSMenu?
    private var providerMenuItems: [ProviderKind: NSMenuItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = StatusModel(store: store, service: service)
        self.statusModel = model

        let controller = CapsuleWindowController(model: model)
        self.capsuleController = controller
        controller.show()

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

        let providerItem = NSMenuItem(title: "Provider", action: nil, keyEquivalent: "")
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Change Project...", action: #selector(changeProject), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Reveal Project", action: #selector(revealProject), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Codex Status Monitor", action: #selector(quit), keyEquivalent: "q"))
        self.statusMenu = menu
        capsuleController?.contextMenu = menu
        refreshProviderMenuState()
    }

    @objc private func selectProvider(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let provider = ProviderKind(rawValue: rawValue)
        else {
            return
        }

        statusModel?.selectProvider(provider)
        refreshProviderMenuState()
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
        }
    }

    private func refreshProviderMenuState() {
        let selectedProvider = store.selectedProvider
        for (provider, item) in providerMenuItems {
            item.state = provider == selectedProvider ? .on : .off
        }
    }
}

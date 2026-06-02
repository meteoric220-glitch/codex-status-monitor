import AppKit
import SwiftUI

@MainActor
final class CapsuleWindowController: NSObject {
    private let model: StatusModel
    private let window: CapsuleWindow
    var contextMenu: NSMenu? {
        didSet {
            window.contextMenu = contextMenu
        }
    }

    init(model: StatusModel) {
        self.model = model

        let view = CapsuleView(model: model)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 170, height: 52)

        self.window = CapsuleWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = false
    }

    func show() {
        positionWindow()
        window.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.positionWindow()
            }
        }
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else {
            return
        }

        let frame = screen.visibleFrame
        let size = window.frame.size
        let x = frame.maxX - size.width - 18
        let y = frame.maxY - size.height - 10
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

final class CapsuleWindow: NSWindow {
    var contextMenu: NSMenu?

    override var canBecomeKey: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if event.type == .rightMouseDown {
            showContextMenu(event)
        } else {
            super.mouseDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        showContextMenu(event)
    }

    private func showContextMenu(_ event: NSEvent) {
        guard let contextMenu else {
            return
        }
        NSMenu.popUpContextMenu(contextMenu, with: event, for: contentView ?? NSView())
    }
}

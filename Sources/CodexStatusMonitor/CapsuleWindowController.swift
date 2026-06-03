import AppKit
import SwiftUI

private enum NotchLayout {
    static let closedHeight: CGFloat = 32
    static let topCornerRadius: CGFloat = 6
    static let bottomCornerRadius: CGFloat = 14
    static let logoSize: CGFloat = 20
    static let horizontalInset: CGFloat = 8
    static let contentSpacing: CGFloat = 6
    static let maxTextWidth: CGFloat = 72
    static let textHeight: CGFloat = 16
    static let fallbackNotchWidth: CGFloat = 185
}

@MainActor
final class CapsuleWindowController: NSObject {
    private let model: StatusModel
    private let visualWindow: NotchVisualPanel
    private let interactionWindow: LogoInteractionPanel
    private let hostingView: NotchHostingView

    var contextMenu: NSMenu? {
        didSet {
            interactionWindow.contextMenu = contextMenu
        }
    }

    init(model: StatusModel) {
        self.model = model

        let initialLayout = Self.panelLayout(on: NSScreen.main)
        let contentView = NotchContainerView(model: model, layout: initialLayout)
        let hostingView = NotchHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: initialLayout.panelFrame.size)
        hostingView.autoresizingMask = [.width, .height]

        self.visualWindow = NotchVisualPanel(
            contentRect: initialLayout.panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.interactionWindow = LogoInteractionPanel(
            contentRect: initialLayout.logoScreenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.hostingView = hostingView

        super.init()

        configureVisualWindow()
        configureInteractionWindow()
    }

    func show() {
        positionWindow()
        visualWindow.orderFrontRegardless()
        interactionWindow.orderFrontRegardless()

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

    private func configureVisualWindow() {
        visualWindow.contentView = hostingView
        visualWindow.isReleasedWhenClosed = false
        visualWindow.backgroundColor = .clear
        visualWindow.isOpaque = false
        visualWindow.hasShadow = false
        visualWindow.level = .screenSaver
        visualWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        visualWindow.ignoresMouseEvents = true
    }

    private func configureInteractionWindow() {
        interactionWindow.isReleasedWhenClosed = false
        interactionWindow.backgroundColor = .clear
        interactionWindow.isOpaque = false
        interactionWindow.hasShadow = false
        interactionWindow.level = .screenSaver
        interactionWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        interactionWindow.ignoresMouseEvents = false
        interactionWindow.onPrimaryClick = { [weak model] in
            model?.expandTemporarily()
        }
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else {
            return
        }

        let layout = Self.panelLayout(on: screen)
        hostingView.frame = NSRect(origin: .zero, size: layout.panelFrame.size)
        hostingView.rootView = NotchContainerView(model: model, layout: layout)
        visualWindow.setFrame(layout.panelFrame, display: true)
        interactionWindow.setFrame(layout.logoScreenFrame, display: true)
    }

    private static func panelLayout(on screen: NSScreen?) -> NotchPanelLayout {
        guard let screen else {
            let panelFrame = NSRect(x: 0, y: 0, width: 640, height: 360)
            let hardwareNotchFrame = NSRect(
                x: panelFrame.midX - NotchLayout.fallbackNotchWidth / 2,
                y: panelFrame.maxY - NotchLayout.closedHeight,
                width: NotchLayout.fallbackNotchWidth,
                height: NotchLayout.closedHeight
            )
            let logoFrame = NSRect(
                x: hardwareNotchFrame.maxX + NotchLayout.horizontalInset,
                y: hardwareNotchFrame.midY - NotchLayout.logoSize / 2,
                width: NotchLayout.logoSize,
                height: NotchLayout.logoSize
            )
            return NotchPanelLayout(panelFrame: panelFrame, hardwareNotchFrame: hardwareNotchFrame, logoFrame: logoFrame)
        }

        let screenFrame = screen.frame
        let panelFrame = NSRect(
            x: screenFrame.midX - screenFrame.width / 4,
            y: screenFrame.maxY - screenFrame.height / 2,
            width: screenFrame.width / 2,
            height: screenFrame.height / 2
        )
        let hardwareNotchFrame = screen.notchFrameWithMenubarAsBackup.offsetBy(
            dx: -panelFrame.minX,
            dy: -panelFrame.minY
        )
        let logoFrame = NSRect(
            x: hardwareNotchFrame.maxX + NotchLayout.horizontalInset,
            y: hardwareNotchFrame.midY - NotchLayout.logoSize / 2,
            width: NotchLayout.logoSize,
            height: NotchLayout.logoSize
        )

        return NotchPanelLayout(panelFrame: panelFrame, hardwareNotchFrame: hardwareNotchFrame, logoFrame: logoFrame)
    }
}

private struct NotchPanelLayout {
    let panelFrame: NSRect
    let hardwareNotchFrame: NSRect
    let logoFrame: NSRect

    var logoScreenFrame: NSRect {
        logoFrame.offsetBy(dx: panelFrame.minX, dy: panelFrame.minY)
    }
}

private struct NotchContainerView: View {
    @ObservedObject var model: StatusModel
    let layout: NotchPanelLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            ZStack {
                NotchShape()
                    .fill(.black)
                    .frame(width: backgroundFrame.width, height: backgroundFrame.height)

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                        .frame(width: layout.hardwareNotchFrame.width)

                    HStack(spacing: NotchLayout.contentSpacing) {
                        LogoStatusView(status: model.snapshot.status)
                            .provider(model.provider)
                            .frame(width: NotchLayout.logoSize, height: NotchLayout.logoSize)

                        if model.isExpanded {
                            Text(model.snapshot.detail)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.92))
                                .lineLimit(1)
                                .frame(width: NotchLayout.maxTextWidth, height: NotchLayout.textHeight, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .frame(width: trailingContentWidth, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, NotchLayout.horizontalInset)
            }
            .frame(width: backgroundFrame.width, height: backgroundFrame.height)
            .offset(
                x: backgroundFrame.minX,
                y: layout.panelFrame.height - backgroundFrame.maxY
            )
        }
        .frame(width: layout.panelFrame.width, height: layout.panelFrame.height)
    }

    private var backgroundFrame: NSRect {
        NSRect(
            x: layout.hardwareNotchFrame.minX,
            y: layout.hardwareNotchFrame.minY,
            width: layout.hardwareNotchFrame.width + trailingContentWidth + NotchLayout.horizontalInset * 2,
            height: layout.hardwareNotchFrame.height
        )
    }

    private var trailingContentWidth: CGFloat {
        if model.isExpanded {
            return NotchLayout.logoSize + NotchLayout.contentSpacing + NotchLayout.maxTextWidth
        }
        return NotchLayout.logoSize
    }
}

private struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topRadius = NotchLayout.topCornerRadius
        let bottomRadius = NotchLayout.bottomCornerRadius
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: minX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: maxX - bottomRadius, y: maxY),
            control: CGPoint(x: maxX, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX + bottomRadius, y: maxY))
        path.addQuadCurve(
            to: CGPoint(x: minX, y: maxY - bottomRadius),
            control: CGPoint(x: minX, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX, y: minY + topRadius))
        path.addQuadCurve(
            to: CGPoint(x: minX + topRadius, y: minY),
            control: CGPoint(x: minX, y: minY)
        )
        path.closeSubpath()
        return path
    }
}

private final class NotchHostingView: NSHostingView<NotchContainerView> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private extension NSScreen {
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    var notchSize: NSSize {
        guard
            let topLeftArea = auxiliaryTopLeftArea,
            let topRightArea = auxiliaryTopRightArea,
            hasNotch
        else {
            return NSSize(width: NotchLayout.fallbackNotchWidth, height: menubarHeight)
        }

        return NSSize(
            width: frame.width - topLeftArea.width - topRightArea.width,
            height: safeAreaInsets.top
        )
    }

    var notchFrame: NSRect {
        NSRect(
            x: frame.midX - notchSize.width / 2,
            y: frame.maxY - notchSize.height,
            width: notchSize.width,
            height: notchSize.height
        )
    }

    var menubarHeight: CGFloat {
        max(frame.maxY - visibleFrame.maxY, NotchLayout.closedHeight)
    }

    var notchFrameWithMenubarAsBackup: NSRect {
        guard hasNotch else {
            return NSRect(
                x: frame.midX - NotchLayout.fallbackNotchWidth / 2,
                y: frame.maxY - menubarHeight,
                width: NotchLayout.fallbackNotchWidth,
                height: menubarHeight
            )
        }

        return notchFrame
    }
}

final class NotchVisualPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class LogoInteractionPanel: NSPanel {
    var contextMenu: NSMenu?
    var onPrimaryClick: (() -> Void)?

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        onPrimaryClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let contextMenu else {
            return
        }
        NSMenu.popUpContextMenu(contextMenu, with: event, for: contentView ?? NSView())
    }
}

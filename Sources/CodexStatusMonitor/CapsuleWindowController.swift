import AppKit
import CodexStatusMonitorCore
import SwiftUI

private enum NotchLayout {
    static let closedHeight: CGFloat = 32
    static let topCornerRadius: CGFloat = 6
    static let bottomCornerRadius: CGFloat = 14
    static let logoSize: CGFloat = 20
    static let horizontalInset: CGFloat = 8
    static let logoNotchGap: CGFloat = 5
    static let contentSpacing: CGFloat = 6
    static let maxTextWidth: CGFloat = 140
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

    var onDoubleClick: (() -> Void)? {
        didSet {
            interactionWindow.onDoubleClick = onDoubleClick
        }
    }

    init(model: StatusModel) {
        self.model = model

        let initialLayout = Self.panelLayout(on: NSScreen.main, indicatorSide: model.indicatorSide)
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

    func positionWindow() {
        guard let screen = NSScreen.main else {
            return
        }

        let layout = Self.panelLayout(on: screen, indicatorSide: model.indicatorSide)
        hostingView.frame = NSRect(origin: .zero, size: layout.panelFrame.size)
        hostingView.rootView = NotchContainerView(model: model, layout: layout)
        visualWindow.setFrame(layout.panelFrame, display: true)
        interactionWindow.setFrame(layout.logoScreenFrame, display: true)
    }

    private static func panelLayout(on screen: NSScreen?, indicatorSide: IndicatorSide) -> NotchPanelLayout {
        guard let screen else {
            let panelFrame = NSRect(x: 0, y: 0, width: 640, height: 360)
            let hardwareNotchFrame = NSRect(
                x: panelFrame.midX - NotchLayout.fallbackNotchWidth / 2,
                y: panelFrame.maxY - NotchLayout.closedHeight,
                width: NotchLayout.fallbackNotchWidth,
                height: NotchLayout.closedHeight
            )
            return NotchPanelLayout(
                panelFrame: panelFrame,
                hardwareNotchFrame: hardwareNotchFrame,
                indicatorSide: indicatorSide
            )
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
        return NotchPanelLayout(
            panelFrame: panelFrame,
            hardwareNotchFrame: hardwareNotchFrame,
            indicatorSide: indicatorSide
        )
    }
}

private struct NotchPanelLayout {
    let panelFrame: NSRect
    let hardwareNotchFrame: NSRect
    let indicatorSide: IndicatorSide

    var logoScreenFrame: NSRect {
        logoFrame.offsetBy(dx: panelFrame.minX, dy: panelFrame.minY)
    }

    var logoFrame: NSRect {
        let x: CGFloat
        switch indicatorSide {
        case .left:
            x = hardwareNotchFrame.minX - NotchLayout.logoNotchGap - NotchLayout.logoSize
        case .right:
            x = hardwareNotchFrame.maxX + NotchLayout.logoNotchGap
        }
        return NSRect(
            x: x,
            y: hardwareNotchFrame.midY - NotchLayout.logoSize / 2,
            width: NotchLayout.logoSize,
            height: NotchLayout.logoSize
        )
    }
}

private struct NotchContainerView: View {
    @ObservedObject var model: StatusModel
    let layout: NotchPanelLayout
    @State private var measuredTextWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            ZStack {
                NotchShape(side: layout.indicatorSide)
                    .fill(.black)
                    .frame(width: backgroundFrame.width, height: backgroundFrame.height)

                contentStack
                    .padding(.leading, leadingContentInset)
                    .padding(.trailing, trailingContentInset)
            }
            .frame(width: backgroundFrame.width, height: backgroundFrame.height)
            .offset(
                x: backgroundFrame.minX,
                y: layout.panelFrame.height - backgroundFrame.maxY
            )
        }
        .frame(width: layout.panelFrame.width, height: layout.panelFrame.height)
        .background(textWidthReader)
        .onPreferenceChange(StatusTextWidthPreferenceKey.self) { measuredTextWidth = $0 }
    }

    @ViewBuilder
    private var contentStack: some View {
        if layout.indicatorSide == .right {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(width: layout.hardwareNotchFrame.width)
                indicatorContent
                    .frame(width: contentWidth, alignment: .leading)
            }
        } else {
            HStack(spacing: 0) {
                indicatorContent
                    .frame(width: contentWidth, alignment: .trailing)
                Spacer(minLength: 0)
                    .frame(width: layout.hardwareNotchFrame.width)
            }
        }
    }

    @ViewBuilder
    private var indicatorContent: some View {
        if layout.indicatorSide == .right {
            HStack(spacing: NotchLayout.contentSpacing) {
                logo
                expandedText(alignment: .leading, edge: .trailing)
            }
        } else {
            HStack(spacing: NotchLayout.contentSpacing) {
                expandedText(alignment: .trailing, edge: .leading)
                logo
            }
        }
    }

    private var logo: some View {
        LogoStatusView(status: model.snapshot.status)
            .provider(model.provider)
            .frame(width: NotchLayout.logoSize, height: NotchLayout.logoSize)
    }

    @ViewBuilder
    private func expandedText(alignment: Alignment, edge: Edge) -> some View {
        if model.isExpanded {
            Text(model.snapshot.detail)
                .font(statusTextFont)
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: textWidth, height: NotchLayout.textHeight, alignment: alignment)
                .transition(.opacity.combined(with: .move(edge: edge)))
        }
    }

    private var textWidthReader: some View {
        Text(model.snapshot.detail)
            .font(statusTextFont)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: StatusTextWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            )
            .hidden()
    }

    private var statusTextFont: Font {
        .system(size: 12, weight: .semibold, design: .rounded)
    }

    private var backgroundFrame: NSRect {
        let width = layout.hardwareNotchFrame.width + contentWidth + NotchLayout.horizontalInset * 2
        let x: CGFloat
        switch layout.indicatorSide {
        case .left:
            x = layout.hardwareNotchFrame.maxX - width
        case .right:
            x = layout.hardwareNotchFrame.minX
        }

        return NSRect(
            x: x,
            y: layout.hardwareNotchFrame.minY,
            width: width,
            height: layout.hardwareNotchFrame.height
        )
    }

    private var contentWidth: CGFloat {
        if model.isExpanded {
            return NotchLayout.logoSize + NotchLayout.contentSpacing + textWidth
        }
        return NotchLayout.logoSize
    }

    private var textWidth: CGFloat {
        min(max(measuredTextWidth, 0), NotchLayout.maxTextWidth)
    }

    private var leadingContentInset: CGFloat {
        switch layout.indicatorSide {
        case .left:
            return NotchLayout.horizontalInset * 2 - NotchLayout.logoNotchGap
        case .right:
            return NotchLayout.logoNotchGap
        }
    }

    private var trailingContentInset: CGFloat {
        switch layout.indicatorSide {
        case .left:
            return NotchLayout.logoNotchGap
        case .right:
            return NotchLayout.horizontalInset * 2 - NotchLayout.logoNotchGap
        }
    }
}

private struct StatusTextWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct NotchShape: Shape {
    let side: IndicatorSide

    func path(in rect: CGRect) -> Path {
        let topRadius = NotchLayout.topCornerRadius
        let bottomRadius = NotchLayout.bottomCornerRadius
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
            control: CGPoint(x: rect.minX + topRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius + bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius - bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topRadius, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
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
    var onDoubleClick: (() -> Void)?

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            onDoubleClick?()
        } else {
            onPrimaryClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let contextMenu else {
            return
        }
        NSMenu.popUpContextMenu(contextMenu, with: event, for: contentView ?? NSView())
    }
}

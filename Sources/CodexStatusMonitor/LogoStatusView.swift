import AppKit
import CodexStatusMonitorCore
import SwiftUI

struct LogoStatusView: View {
    let status: MonitorStatus
    var provider: ProviderKind = .codex

    @State private var doneSettle = false

    var body: some View {
        if provider == .claude {
            ClaudeNativeLogoView(status: status)
                .accessibilityLabel(status.displayText)
        } else {
            codexLogo
                .onAppear {
                    restartAnimation()
                }
                .onChange(of: status) {
                    restartAnimation()
                }
                .accessibilityLabel(status.displayText)
        }
    }

    private var codexLogo: some View {
        Group {
            switch status {
            case .working:
                TimelineView(.animation) { context in
                    logoMask
                        .overlay(workingGradient(at: context.date).mask(logoMask))
                }
            case .waiting:
                TimelineView(.animation) { context in
                    logoMask
                        .foregroundStyle(statusColor)
                        .opacity(waitingOpacity(at: context.date))
                }
            case .done:
                logoMask
                    .foregroundStyle(statusColor)
                    .scaleEffect(doneSettle ? 1.06 : 1)
                    .animation(.spring(response: 0.24, dampingFraction: 0.72), value: doneSettle)
            case .setup, .error:
                logoMask
                    .foregroundStyle(statusColor)
                    .opacity(status == .setup ? 0.65 : 0.7)
            }
        }
    }

    private var logoMask: some View {
        Group {
            if let image = ProviderLogoLoader.load(for: provider) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                ProviderFallbackLogo(provider: provider)
            }
        }
    }

    private func workingGradient(at date: Date) -> some View {
        let period = 2.4
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let sweep = 0.5 - 0.5 * cos(phase * 2 * .pi)
        let offset = -0.65 + sweep * 1.3

        return LinearGradient(
            colors: [
                Color(hex: 0x004993),
                Color(hex: 0x2D7DD2),
                Color(hex: 0x6CB5FF),
                Color(hex: 0x2D7DD2),
                Color(hex: 0x004993)
            ],
            startPoint: UnitPoint(x: offset, y: -0.2),
            endPoint: UnitPoint(x: offset + 1.0, y: 1.2)
        )
    }

    private func waitingOpacity(at date: Date) -> Double {
        let cycleDuration = 1.45
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)

        switch phase {
        case 0..<0.14:
            return interpolate(from: 0.35, to: 1.0, progress: phase / 0.14)
        case 0.14..<0.32:
            return interpolate(from: 1.0, to: 0.55, progress: (phase - 0.14) / 0.18)
        case 0.32..<0.48:
            return interpolate(from: 0.55, to: 1.0, progress: (phase - 0.32) / 0.16)
        case 0.48..<0.68:
            return interpolate(from: 1.0, to: 0.65, progress: (phase - 0.48) / 0.2)
        default:
            return 0.65
        }
    }

    private func interpolate(from start: Double, to end: Double, progress: Double) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        let eased = 0.5 - 0.5 * cos(clampedProgress * .pi)
        return start + (end - start) * eased
    }

    private var statusColor: Color {
        switch status {
        case .setup, .error:
            return Color(hex: 0x8E8E93)
        case .done:
            return Color(hex: 0x34C759)
        case .waiting:
            return Color(hex: 0xFFD60A)
        case .working:
            return Color(hex: 0x004993)
        }
    }

    private func restartAnimation() {
        doneSettle = false

        DispatchQueue.main.async {
            if status == .done {
                doneSettle = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    doneSettle = false
                }
            }
        }
    }
}

private struct ProviderFallbackLogo: View {
    let provider: ProviderKind

    var body: some View {
        Text(String(provider.displayName.prefix(1)))
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClaudeNativeLogoView: View {
    let status: MonitorStatus

    var body: some View {
        TimelineView(.animation) { context in
            nativeLogo
                .rotationEffect(.degrees(rotationAngle(at: context.date)))
                .saturation(status == .setup || status == .error ? 0 : 1)
                .opacity(status == .setup || status == .error ? 0.7 : 1)
        }
    }

    private var nativeLogo: some View {
        Group {
            if let image = ProviderLogoLoader.loadNative(for: .claude) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                ProviderFallbackLogo(provider: .claude)
            }
        }
    }

    private func rotationAngle(at date: Date) -> Double {
        switch status {
        case .working:
            return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8 * 360
        case .waiting:
            return waitingAngle(at: date)
        case .done, .setup, .error:
            return 0
        }
    }

    private func waitingAngle(at date: Date) -> Double {
        let halfSwingDuration = 0.35
        let pauseDuration = 0.65
        let activeDuration = halfSwingDuration * 4
        let cycleDuration = activeDuration + pauseDuration
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)

        guard phase < activeDuration else {
            return -15
        }

        let segment = Int(phase / halfSwingDuration)
        let progress = (phase - Double(segment) * halfSwingDuration) / halfSwingDuration
        let eased = 0.5 - 0.5 * cos(progress * .pi)

        switch segment {
        case 0, 2:
            return -15 + eased * 30
        default:
            return 15 - eased * 30
        }
    }
}

@MainActor
private enum ProviderLogoLoader {
    private static var codexTemplateImage: NSImage?
    private static var claudeTemplateImage: NSImage?
    private static var codexNativeImage: NSImage?
    private static var claudeNativeImage: NSImage?

    static func load(for provider: ProviderKind) -> NSImage? {
        loadCached(provider: provider, isTemplate: true)
    }

    static func loadNative(for provider: ProviderKind) -> NSImage? {
        loadCached(provider: provider, isTemplate: false)
    }

    private static func loadCached(provider: ProviderKind, isTemplate: Bool) -> NSImage? {
        if let image = cachedImage(for: provider, isTemplate: isTemplate) {
            return image
        }

        guard let resourceURL = Bundle.module.url(forResource: provider.lobeIconResourceName, withExtension: "png"),
              let image = NSImage(contentsOf: resourceURL) else {
            return nil
        }

        image.isTemplate = isTemplate
        setCachedImage(image, for: provider, isTemplate: isTemplate)
        return image
    }

    private static func cachedImage(for provider: ProviderKind, isTemplate: Bool) -> NSImage? {
        switch (provider, isTemplate) {
        case (.codex, true):
            return codexTemplateImage
        case (.claude, true):
            return claudeTemplateImage
        case (.codex, false):
            return codexNativeImage
        case (.claude, false):
            return claudeNativeImage
        }
    }

    private static func setCachedImage(_ image: NSImage, for provider: ProviderKind, isTemplate: Bool) {
        switch (provider, isTemplate) {
        case (.codex, true):
            codexTemplateImage = image
        case (.claude, true):
            claudeTemplateImage = image
        case (.codex, false):
            codexNativeImage = image
        case (.claude, false):
            claudeNativeImage = image
        }
    }
}

private extension ProviderKind {
    var lobeIconResourceName: String {
        switch self {
        case .codex:
            return "lobe-codex"
        case .claude:
            return "lobe-claude-color"
        }
    }
}

extension LogoStatusView {
    func provider(_ provider: ProviderKind) -> LogoStatusView {
        var copy = self
        copy.provider = provider
        return copy
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

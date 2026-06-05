import AppKit
import CodexStatusMonitorCore
import SwiftUI

struct LogoStatusView: View {
    let status: MonitorStatus
    var provider: ProviderKind = .codex

    @State private var waitingPulse = false
    @State private var workingPulse = false
    @State private var gradientShift = false

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
                logoMask
                    .overlay(workingGradient.mask(logoMask))
                    .scaleEffect(workingPulse ? 1.04 : 0.96)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: workingPulse)
                    .animation(.linear(duration: 1.8).repeatForever(autoreverses: true), value: gradientShift)
            case .waiting:
                logoMask
                    .foregroundStyle(statusColor)
                    .opacity(waitingPulse ? 1.0 : 0.25)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: waitingPulse)
            default:
                logoMask
                    .foregroundStyle(statusColor)
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

    private var workingGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: 0x004993),
                Color(hex: 0x6CB5FF),
                Color(hex: 0x004993)
            ],
            startPoint: gradientShift ? .trailing : .leading,
            endPoint: gradientShift ? .leading : .trailing
        )
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
        waitingPulse = false
        workingPulse = false
        gradientShift = false

        DispatchQueue.main.async {
            if status == .waiting {
                waitingPulse = true
            }
            if status == .working {
                workingPulse = true
                gradientShift = true
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

private enum ProviderLogoLoader {
    static func load(for provider: ProviderKind) -> NSImage? {
        guard let resourceURL = Bundle.module.url(forResource: provider.lobeIconResourceName, withExtension: "png"),
              let image = NSImage(contentsOf: resourceURL) else {
            return nil
        }

        image.isTemplate = true
        return image
    }

    static func loadNative(for provider: ProviderKind) -> NSImage? {
        guard let resourceURL = Bundle.module.url(forResource: provider.lobeIconResourceName, withExtension: "png"),
              let image = NSImage(contentsOf: resourceURL) else {
            return nil
        }

        image.isTemplate = false
        return image
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

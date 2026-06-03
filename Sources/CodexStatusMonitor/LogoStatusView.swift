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
        .onAppear {
            restartAnimation()
        }
        .onChange(of: status) {
            restartAnimation()
        }
        .accessibilityLabel(status.displayText)
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

private enum ProviderLogoLoader {
    static func load(for provider: ProviderKind) -> NSImage? {
        guard let resourceURL = Bundle.module.url(forResource: provider.lobeIconResourceName, withExtension: "png"),
              let image = NSImage(contentsOf: resourceURL) else {
            return nil
        }

        image.isTemplate = true
        return image
    }
}

private extension ProviderKind {
    var lobeIconResourceName: String {
        switch self {
        case .codex:
            return "lobe-codex"
        case .claude:
            return "lobe-claude"
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

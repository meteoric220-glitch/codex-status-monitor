import AppKit
import CodexStatusMonitorCore
import SwiftUI

struct LogoStatusView: View {
    let status: MonitorStatus

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
        Image(nsImage: CodexLogoLoader.load())
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
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

enum CodexLogoLoader {
    static func load() -> NSImage {
        let installedLogoPath = "/Applications/Codex.app/Contents/Resources/codexTemplate@2x.png"
        if let image = NSImage(contentsOfFile: installedLogoPath) {
            return image
        }

        if let resourceURL = Bundle.module.url(forResource: "codexTemplate@2x", withExtension: "png"),
           let image = NSImage(contentsOf: resourceURL) {
            return image
        }

        return NSImage(size: NSSize(width: 22, height: 22), flipped: false) { rect in
            NSColor.white.setFill()
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6)
            path.fill()
            return true
        }
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

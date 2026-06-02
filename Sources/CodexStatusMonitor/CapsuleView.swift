import CodexStatusMonitorCore
import SwiftUI

struct CapsuleView: View {
    @ObservedObject var model: StatusModel

    var body: some View {
        Button {
            model.expandTemporarily()
        } label: {
            HStack(spacing: 10) {
                LogoStatusView(status: model.snapshot.status)
                    .frame(width: 22, height: 22)

                if model.isExpanded {
                    Text(model.snapshot.detail)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(width: model.isExpanded ? 148 : 56, height: 36)
            .background(.black.opacity(0.72), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .padding(8)
    }

    private var helpText: String {
        if let projectName = model.snapshot.projectName {
            return "\(projectName): \(model.snapshot.detail)"
        }
        return model.snapshot.detail
    }
}

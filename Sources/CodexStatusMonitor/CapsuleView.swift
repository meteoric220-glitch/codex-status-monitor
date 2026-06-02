import SwiftUI

struct CapsuleView: View {
    @ObservedObject var model: StatusModel

    var body: some View {
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
    }
}

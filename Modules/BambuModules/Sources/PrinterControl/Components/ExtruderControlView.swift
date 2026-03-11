import SwiftUI

struct ExtruderControlView: View {
    let viewModel: ControlViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.retract()
            } label: {
                Label("Retract", systemImage: "arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.extrude()
            } label: {
                Label("Extrude", systemImage: "arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    ExtruderControlView(viewModel: .preview)
        .padding()
}

import SFSafeSymbols
import SwiftUI

struct ExtruderControlView: View {
    let viewModel: ControlViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.retract()
            } label: {
                Label("Retract", systemSymbol: .arrowUp)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.extrude()
            } label: {
                Label("Extrude", systemSymbol: .arrowDown)
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

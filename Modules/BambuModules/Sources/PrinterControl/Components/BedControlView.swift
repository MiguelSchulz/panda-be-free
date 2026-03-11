import BambuUI
import SwiftUI

struct BedControlView: View {
    let viewModel: ControlViewModel

    var body: some View {
        VStack(spacing: 4) {
            DirectionalButton(systemImage: "chevron.up.2") {
                viewModel.jogZ(distance: 10)
            }
            DirectionalButton(systemImage: "chevron.up") {
                viewModel.jogZ(distance: 1)
            }

            VStack(spacing: 2) {
                Image(systemName: "square.stack.3d.up")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Bed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 52)

            DirectionalButton(systemImage: "chevron.down") {
                viewModel.jogZ(distance: -1)
            }
            DirectionalButton(systemImage: "chevron.down.2") {
                viewModel.jogZ(distance: -10)
            }
        }
    }
}

#Preview {
    BedControlView(viewModel: .preview)
        .padding()
}

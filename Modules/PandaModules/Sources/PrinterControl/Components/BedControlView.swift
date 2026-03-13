import PandaUI
import SFSafeSymbols
import SwiftUI

struct BedControlView: View {
    let viewModel: ControlViewModel

    var body: some View {
        VStack(spacing: 4) {
            DirectionalButton(systemSymbol: .chevronUp2) {
                viewModel.jogZ(distance: -10)
            }
            DirectionalButton(systemSymbol: .chevronUp) {
                viewModel.jogZ(distance: -1)
            }

            VStack(spacing: 2) {
                Image(systemSymbol: .squareStack3dUp)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Bed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 52)

            DirectionalButton(systemSymbol: .chevronDown) {
                viewModel.jogZ(distance: 1)
            }
            DirectionalButton(systemSymbol: .chevronDown2) {
                viewModel.jogZ(distance: 10)
            }
        }
    }
}

#Preview {
    BedControlView(viewModel: .preview)
        .padding()
}

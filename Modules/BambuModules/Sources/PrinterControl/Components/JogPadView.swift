import BambuUI
import SwiftUI

struct JogPadView: View {
    let viewModel: ControlViewModel

    var body: some View {
        VStack(spacing: 4) {
            // Up: 10mm then 1mm (outer to inner)
            VStack(spacing: 4) {
                DirectionalButton(systemImage: "chevron.up.2") {
                    viewModel.jogY(distance: 10)
                }
                DirectionalButton(systemImage: "chevron.up") {
                    viewModel.jogY(distance: 1)
                }
            }

            HStack(spacing: 4) {
                // Left: 10mm then 1mm (outer to inner)
                HStack(spacing: 4) {
                    DirectionalButton(systemImage: "chevron.left.2") {
                        viewModel.jogX(distance: -10)
                    }
                    DirectionalButton(systemImage: "chevron.left") {
                        viewModel.jogX(distance: -1)
                    }
                }

                Button { viewModel.homeAll() } label: {
                    Image(systemName: "house.fill")
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                // Right: 1mm then 10mm (inner to outer)
                HStack(spacing: 4) {
                    DirectionalButton(systemImage: "chevron.right") {
                        viewModel.jogX(distance: 1)
                    }
                    DirectionalButton(systemImage: "chevron.right.2") {
                        viewModel.jogX(distance: 10)
                    }
                }
            }

            // Down: 1mm then 10mm (inner to outer)
            VStack(spacing: 4) {
                DirectionalButton(systemImage: "chevron.down") {
                    viewModel.jogY(distance: -1)
                }
                DirectionalButton(systemImage: "chevron.down.2") {
                    viewModel.jogY(distance: -10)
                }
            }
        }
    }
}

#Preview {
    JogPadView(viewModel: .preview)
        .padding()
}

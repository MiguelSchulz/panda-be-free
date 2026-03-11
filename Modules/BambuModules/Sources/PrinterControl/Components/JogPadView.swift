import BambuUI
import SFSafeSymbols
import SwiftUI

struct JogPadView: View {
    let viewModel: ControlViewModel

    var body: some View {
        VStack(spacing: 4) {
            // Up: 10mm then 1mm (outer to inner)
            VStack(spacing: 4) {
                DirectionalButton(systemSymbol: .chevronUp2) {
                    viewModel.jogY(distance: 10)
                }
                DirectionalButton(systemSymbol: .chevronUp) {
                    viewModel.jogY(distance: 1)
                }
            }

            HStack(spacing: 4) {
                // Left: 10mm then 1mm (outer to inner)
                HStack(spacing: 4) {
                    DirectionalButton(systemSymbol: .chevronLeft2) {
                        viewModel.jogX(distance: -10)
                    }
                    DirectionalButton(systemSymbol: .chevronLeft) {
                        viewModel.jogX(distance: -1)
                    }
                }

                Button { viewModel.homeAll() } label: {
                    Image(systemSymbol: .houseFill)
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(.plain)

                // Right: 1mm then 10mm (inner to outer)
                HStack(spacing: 4) {
                    DirectionalButton(systemSymbol: .chevronRight) {
                        viewModel.jogX(distance: 1)
                    }
                    DirectionalButton(systemSymbol: .chevronRight2) {
                        viewModel.jogX(distance: 10)
                    }
                }
            }

            // Down: 1mm then 10mm (inner to outer)
            VStack(spacing: 4) {
                DirectionalButton(systemSymbol: .chevronDown) {
                    viewModel.jogY(distance: -1)
                }
                DirectionalButton(systemSymbol: .chevronDown2) {
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

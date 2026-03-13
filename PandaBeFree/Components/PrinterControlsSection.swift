import SFSafeSymbols
import SwiftUI

struct PrinterControlsSection: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        HStack(spacing: 16) {
            if viewModel.canPause {
                Button {
                    viewModel.showPauseConfirmation = true
                } label: {
                    Label("Pause", systemSymbol: .pauseFill)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .confirmationDialog("Pause Print?", isPresented: $viewModel.showPauseConfirmation) {
                    Button("Pause Print") {
                        viewModel.pausePrint()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The printer will finish its current move and pause.")
                }
            }

            if viewModel.canResume {
                Button {
                    viewModel.resumePrint()
                } label: {
                    Label("Resume", systemSymbol: .playFill)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            if viewModel.isPrinting || viewModel.canResume {
                Button {
                    viewModel.showStopConfirmation = true
                } label: {
                    Label("Stop", systemSymbol: .stopFill)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .confirmationDialog("Stop Print?", isPresented: $viewModel.showStopConfirmation) {
                    Button("Stop Print", role: .destructive) {
                        viewModel.stopPrint()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will cancel the current print job. This action cannot be undone.")
                }
            }
        }
    }
}

#Preview {
    PrinterControlsSection(viewModel: .preview).padding()
}

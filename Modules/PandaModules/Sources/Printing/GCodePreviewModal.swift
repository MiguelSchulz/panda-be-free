import GCodePreview
import SwiftUI

struct GCodePreviewModal: View {
    @Bindable var viewModel: PrintViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                if let scene = viewModel.previewScene {
                    GCodePreviewView(scene: scene)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView("Preparing preview...")
                }
            }
            .navigationTitle("G-code Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelPreview()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Print") {
                        viewModel.confirmPrint()
                    }
                    .disabled(viewModel.previewScene == nil)
                }
            }
        }
    }
}

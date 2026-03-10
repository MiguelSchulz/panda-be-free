import BambuModels
import BambuUI
import SwiftUI

struct PrintProgressSection: View {
    let state: PrinterAttributes.ContentState

    var body: some View {
        PrintProgressContent(state: state)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Printing") {
    PrintProgressSection(state: .mockPrinting).padding()
}

#Preview("Preparing") {
    PrintProgressSection(state: .mockStarting).padding()
}

#Preview("Completed") {
    PrintProgressSection(state: .mockCompleted).padding()
}

#Preview("Paused") {
    PrintProgressSection(state: .mockPaused).padding()
}

#Preview("Issue") {
    PrintProgressSection(state: .mockIssue).padding()
}

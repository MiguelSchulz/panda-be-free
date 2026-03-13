import SFSafeSymbols
import SwiftUI

struct LightControlSection: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        HStack {
            Label("Chamber Light", systemSymbol: .lightRecessedFill)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { viewModel.chamberLightOn },
                set: { viewModel.toggleLight(on: $0) }
            ))
            .labelsHidden()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    LightControlSection(viewModel: .preview).padding()
}

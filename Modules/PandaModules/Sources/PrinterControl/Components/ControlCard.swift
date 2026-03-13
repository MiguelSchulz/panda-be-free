import SFSafeSymbols
import SwiftUI

struct ControlCard<Content: View>: View {
    let title: LocalizedStringResource
    let systemSymbol: SFSymbol
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
            } icon: {
                Image(systemSymbol: systemSymbol)
            }
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
    }
}

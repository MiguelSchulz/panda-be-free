import SFSafeSymbols
import SwiftUI

public struct InstructionRow: View {
    let marker: Marker
    let text: LocalizedStringKey

    public enum Marker: Sendable {
        case number(Int)
        case icon(SFSymbol)
    }

    public init(number: Int, text: LocalizedStringKey) {
        self.marker = .number(number)
        self.text = text
    }

    public init(icon: SFSymbol, text: LocalizedStringKey) {
        self.marker = .icon(icon)
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            markerView
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var markerView: some View {
        switch marker {
        case let .number(n):
            Text("\(n)")
                .font(.caption2.bold())
                .frame(width: 22, height: 22)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
        case let .icon(symbol):
            Image(systemSymbol: symbol)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 22)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        InstructionRow(number: 1, text: "On your printer's touchscreen, tap **Settings**")
        InstructionRow(number: 2, text: "Navigate to **WLAN** (or Network Settings)")
        InstructionRow(icon: .lockFill, text: "Look for the **lock icon** indicating LAN mode")
    }
    .padding()
}

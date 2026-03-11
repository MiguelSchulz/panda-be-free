import SFSafeSymbols
import SwiftUI

public struct DirectionalButton: View {
    public let systemSymbol: SFSymbol
    public let action: () -> Void

    public init(systemSymbol: SFSymbol, action: @escaping () -> Void) {
        self.systemSymbol = systemSymbol
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemSymbol: systemSymbol)
                .font(.title2)
                .fontWeight(.semibold)
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        DirectionalButton(systemSymbol: .chevronUp) {}
        DirectionalButton(systemSymbol: .chevronDown) {}
        DirectionalButton(systemSymbol: .chevronLeft) {}
        DirectionalButton(systemSymbol: .chevronRight) {}
    }
    .padding()
}

import SwiftUI

public struct DirectionalButton: View {
    public let systemImage: String
    public let action: () -> Void

    public init(systemImage: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
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
        DirectionalButton(systemImage: "chevron.up") {}
        DirectionalButton(systemImage: "chevron.down") {}
        DirectionalButton(systemImage: "chevron.left") {}
        DirectionalButton(systemImage: "chevron.right") {}
    }
    .padding()
}

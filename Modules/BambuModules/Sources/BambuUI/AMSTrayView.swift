import BambuModels
import SwiftUI

public struct AMSTrayView: View {
    public let tray: AMSTray
    public let slotLabel: String
    public let isActive: Bool
    public var onTap: (() -> Void)?

    public init(tray: AMSTray, slotLabel: String, isActive: Bool, onTap: (() -> Void)? = nil) {
        self.tray = tray
        self.slotLabel = slotLabel
        self.isActive = isActive
        self.onTap = onTap
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Slot label (A1, A2, etc.)
            Text(slotLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Spool card
            RoundedRectangle(cornerRadius: 8)
                .fill(tray.color ?? Color(.systemGray5))
                .frame(height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isActive ? .blue : Color(.systemGray3), lineWidth: isActive ? 2.5 : 1)
                )
                .overlay {
                    VStack(spacing: 2) {
                        Group {
                            if let material = tray.materialType {
                                Text(material)
                            } else {
                                Text("Empty")
                            }
                        }
                        .font(.caption)
                        .fontWeight(tray.isEmpty ? .regular : .semibold)
                        .foregroundStyle(tray.isEmpty ? .secondary : textColor)

                        if let remain = tray.remainPercent, tray.isBambuFilament {
                            // Remaining bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.black.opacity(0.15))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(Color.white.opacity(0.8))
                                        .frame(width: geo.size.width * CGFloat(remain) / 100, height: 4)
                                }
                            }
                            .frame(height: 4)
                            .padding(.horizontal, 8)

                            Text("\(remain)%")
                                .font(.system(size: 9))
                                .foregroundStyle(textColor.opacity(0.7))
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
        .onTapGesture { onTap?() }
    }

    private var textColor: Color {
        guard let hex = tray.colorHex, hex.count == 8,
              let value = UInt32(hex, radix: 16) else { return .primary }
        let r = Double((value >> 24) & 0xFF) / 255.0
        let g = Double((value >> 16) & 0xFF) / 255.0
        let b = Double((value >> 8) & 0xFF) / 255.0
        // Perceived brightness
        let brightness = r * 0.299 + g * 0.587 + b * 0.114
        return brightness > 0.6 ? .black : .white
    }
}

#Preview {
    HStack(spacing: 8) {
        AMSTrayView(tray: AMSTray(id: 0, materialType: "PLA", color: .yellow, colorHex: "FFFF00FF",
                                  remainPercent: 85, isBambuFilament: true), slotLabel: "A1", isActive: true)
        AMSTrayView(tray: AMSTray(id: 1, materialType: "ABS", color: .red, colorHex: "FF0000FF",
                                  remainPercent: 42, isBambuFilament: true), slotLabel: "A2", isActive: false)
        AMSTrayView(tray: AMSTray(id: 2, materialType: "PETG", color: .blue, colorHex: "0000FFFF"),
                    slotLabel: "A3", isActive: false)
        AMSTrayView(tray: AMSTray(id: 3), slotLabel: "A4", isActive: false)
    }
    .padding()
}

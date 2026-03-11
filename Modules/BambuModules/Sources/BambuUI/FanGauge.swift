import SwiftUI

public struct FanGauge: View {
    public let label: LocalizedStringResource
    public let speed255: Int
    public let editable: Bool
    public let onValueSet: (Int) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @State private var originalPercent = 0
    @FocusState private var isFocused: Bool

    public init(label: LocalizedStringResource, speed255: Int, editable: Bool, onValueSet: @escaping (Int) -> Void) {
        self.label = label
        self.speed255 = speed255
        self.editable = editable
        self.onValueSet = onValueSet
    }

    public var percent: Int {
        guard speed255 > 0 else { return 0 }
        return Int((Double(speed255) / 255.0 * 100.0).rounded())
    }

    public var body: some View {
        HStack(spacing: 10) {
            SpinningFan(percent: percent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if isEditing {
                    HStack(spacing: 0) {
                        TextField("0", text: $editText)
                            .keyboardType(.numberPad)
                            .focused($isFocused)
                            .fixedSize()
                            .onChange(of: editText) { _, newValue in
                                let filtered = newValue.filter { $0.isWholeNumber }
                                if filtered != newValue { editText = filtered }
                            }
                        Text("%")
                    }
                    .font(.system(.callout, design: .monospaced))
                    .fontWeight(.medium)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { isFocused = false }
                        }
                    }
                } else {
                    Text(percent > 0 ? "\(percent)%" : "Off")
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.medium)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard editable, !isEditing else { return }
            originalPercent = percent
            editText = percent > 0 ? String(percent) : ""
            isEditing = true
            isFocused = true
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, isEditing {
                submitValue()
            }
        }
    }

    private func submitValue() {
        let value = Int(editText) ?? 0
        let clamped = min(max(value, 0), 100)
        if clamped != originalPercent {
            onValueSet(clamped)
        }
        isEditing = false
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        FanGauge(label: "Part Cooling", speed255: 200, editable: true) { _ in }
        FanGauge(label: "Aux Fan", speed255: 128, editable: true) { _ in }
        FanGauge(label: "Hotend", speed255: 200, editable: false) { _ in }
        FanGauge(label: "Chamber", speed255: 0, editable: false) { _ in }
    }
    .padding()
}

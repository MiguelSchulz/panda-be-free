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

                HStack(spacing: 0) {
                    if isEditing {
                        TextField("0", text: $editText)
                            .keyboardType(.numberPad)
                            .font(.system(.callout, design: .monospaced))
                            .focused($isFocused)
                            .fixedSize()
                            .onChange(of: editText) { _, newValue in
                                let filtered = newValue.filter { $0.isWholeNumber }
                                if filtered != newValue { editText = filtered }
                            }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    if #available(iOS 26, *) {
                                        Button("Done") { isFocused = false }
                                            .buttonStyle(.glassProminent)
                                    } else {
                                        Button("Done") { isFocused = false }
                                    }
                                }
                            }
                    } else {
                        Text(percent > 0 ? "\(percent)" : "Off")
                            .font(.system(.callout, design: .monospaced))
                    }
                    if percent > 0 || isEditing {
                        Text("%")
                    }
                }
                .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard editable, !isEditing else { return }
            originalPercent = percent
            editText = percent > 0 ? String(percent) : ""
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                isEditing = true
                isFocused = true
            }
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

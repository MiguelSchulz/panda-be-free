import SwiftUI

public struct TemperatureGauge: View {
    public let label: String
    public let icon: String
    public let current: Int
    public let target: Int?
    public let range: ClosedRange<Int>?
    public let editable: Bool
    public let onValueSet: (Int) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @State private var originalValue = 0
    @FocusState private var isFocused: Bool

    public init(label: String, icon: String, current: Int, target: Int?,
                range: ClosedRange<Int>?, editable: Bool, onValueSet: @escaping (Int) -> Void) {
        self.label = label
        self.icon = icon
        self.current = current
        self.target = target
        self.range = range
        self.editable = editable
        self.onValueSet = onValueSet
    }

    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(gaugeColor)

            if isEditing {
                HStack(spacing: 0) {
                    Text("\(current)/")
                    TextField("0", text: $editText)
                        .keyboardType(.numberPad)
                        .focused($isFocused)
                        .multilineTextAlignment(.center)
                        .fixedSize()
                        .onChange(of: editText) { _, newValue in
                            let filtered = newValue.filter { $0.isWholeNumber }
                            if filtered != newValue { editText = filtered }
                        }
                    Text("\u{00B0}C")
                }
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isFocused = false }
                    }
                }
            } else {
                Text(temperatureText)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard editable, !isEditing else { return }
            originalValue = target ?? 0
            editText = originalValue > 0 ? String(originalValue) : ""
            isEditing = true
            isFocused = true
        }
        .onChange(of: isFocused) { _, focused in
            if !focused && isEditing {
                submitValue()
            }
        }
    }

    private func submitValue() {
        if let range {
            let value = Int(editText) ?? 0
            let clamped = min(max(value, range.lowerBound), range.upperBound)
            if clamped != originalValue {
                onValueSet(clamped)
            }
        }
        isEditing = false
    }

    private var temperatureText: String {
        if let target, target > 0 {
            return "\(current)/\(target)\u{00B0}C"
        }
        return "\(current)\u{00B0}C"
    }

    public var gaugeColor: Color {
        if let target, target > 0 {
            let ratio = target > 0 ? Double(current) / Double(target) : 0
            if ratio >= 0.95 { return .green }
            if ratio >= 0.5 { return .orange }
            return .blue
        }
        return current > 30 ? .orange : .blue
    }
}

#Preview("Heating") {
    HStack {
        TemperatureGauge(
            label: "Nozzle", icon: "flame.fill",
            current: 180, target: 220, range: 0...300, editable: true
        ) { _ in }
        TemperatureGauge(
            label: "Bed", icon: "square.fill",
            current: 58, target: 60, range: 0...110, editable: true
        ) { _ in }
        TemperatureGauge(
            label: "Chamber", icon: "wind",
            current: 28, target: nil, range: nil, editable: false
        ) { _ in }
    }
    .padding()
}

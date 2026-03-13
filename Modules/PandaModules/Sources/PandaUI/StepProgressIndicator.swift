import SwiftUI

public struct StepProgressIndicator: View {
    let current: Int
    let total: Int

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { step in
                if step == current {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 20, height: 8)
                } else {
                    Circle()
                        .fill(step < current ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

#Preview {
    StepProgressIndicator(current: 2, total: 5)
}

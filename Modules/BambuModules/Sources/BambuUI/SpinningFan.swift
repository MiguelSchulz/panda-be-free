import SwiftUI

/// Fan icon that spins continuously at a speed proportional to the percentage.
public struct SpinningFan: View {
    public let percent: Int

    @State private var baseAngle: Double = 0
    @State private var baseTime: Date = .now
    @State private var rate: Double = 0 // degrees per second

    public init(percent: Int) {
        self.percent = percent
    }

    /// Degrees per second: 0 at 0%, 720 at 100%
    private var targetRate: Double {
        guard percent > 0 else { return 0 }
        return Double(percent) / 100.0 * 360.0
    }

    public var body: some View {
        Group {
            if percent > 0 {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(baseTime)
                    let angle = baseAngle + elapsed * rate
                    Image(systemName: "fan.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                        .rotationEffect(.degrees(angle))
                }
            } else {
                Image(systemName: "fan.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: targetRate, initial: true) { oldRate, newRate in
            // Preserve current angle, then continue at new speed
            let now = Date.now
            let elapsed = now.timeIntervalSince(baseTime)
            baseAngle = baseAngle + elapsed * rate
            baseTime = now
            rate = newRate
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        SpinningFan(percent: 0)
        SpinningFan(percent: 50)
        SpinningFan(percent: 100)
    }
    .padding()
}

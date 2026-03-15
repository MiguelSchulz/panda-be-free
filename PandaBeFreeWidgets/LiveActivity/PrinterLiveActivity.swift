import ActivityKit
import PandaModels
import SwiftUI
import WidgetKit

struct PrinterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrinterAttributes.self) { context in
            LiveActivityLockScreenView(
                state: context.state,
                isStale: context.isStale
            )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(
                        state: context.state,
                        isStale: context.isStale
                    )
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                MinimalView(state: context.state)
            }
        }
    }
}

// MARK: - Previews

#Preview(
    "Lock Screen — Printing",
    as: .content,
    using: PrinterAttributes.preview
) {
    PrinterLiveActivity()
} contentStates: {
    PrinterAttributes.ContentState.mockPrinting
}

#Preview(
    "Lock Screen — Preparing",
    as: .content,
    using: PrinterAttributes.preview
) {
    PrinterLiveActivity()
} contentStates: {
    PrinterAttributes.ContentState.mockStarting
}

#Preview(
    "Dynamic Island — Printing",
    as: .dynamicIsland(.expanded),
    using: PrinterAttributes.preview
) {
    PrinterLiveActivity()
} contentStates: {
    PrinterAttributes.ContentState.mockPrinting
}

#Preview(
    "Dynamic Island — Completed",
    as: .dynamicIsland(.compact),
    using: PrinterAttributes.preview
) {
    PrinterLiveActivity()
} contentStates: {
    PrinterAttributes.ContentState.mockCompleted
}

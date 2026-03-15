import ActivityKit
import Foundation
import PandaModels

/// Protocol for Live Activity management, enabling dependency injection and testing.
public protocol LiveActivityManaging: Sendable {
    func startIfNeeded(contentState: PrinterAttributes.ContentState, printerName: String) async
    func update(contentState: PrinterAttributes.ContentState) async
    func endIfNeeded(contentState: PrinterAttributes.ContentState) async
    var isActivityActive: Bool { get }
}

/// Manages the printer Live Activity lifecycle using local-only updates (no APNs).
///
/// Thread-safe and idempotent — safe to call from multiple widgets concurrently.
/// The manager deduplicates updates by checking if content has meaningfully changed.
/// Ensures only one Live Activity exists at a time by ending stale ones on start.
public final class LiveActivityManager: LiveActivityManaging, @unchecked Sendable {
    public static let shared = LiveActivityManager()

    private let staleDuration: TimeInterval = 120 // 2 minutes
    private let completedDismissalDuration: TimeInterval = 14400 // 4 hours

    /// Track last sent state to avoid redundant updates.
    private var lastSentProgress: Int?
    private var lastSentStatus: PrinterStatus?
    private var lastSentRemainingMinutes: Int?

    public init() {}

    public var isActivityActive: Bool {
        !Activity<PrinterAttributes>.activities.isEmpty
    }

    public func startIfNeeded(
        contentState: PrinterAttributes.ContentState,
        printerName: String
    ) async {
        guard LiveActivitySettings.isEnabled else { return }
        guard contentState.status == .preparing || contentState.status == .printing else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // If an activity already exists, just update it — never create a duplicate
        if !Activity<PrinterAttributes>.activities.isEmpty {
            await update(contentState: contentState)
            return
        }

        let attributes = PrinterAttributes(printerName: printerName)
        let content = ActivityContent(
            state: contentState,
            staleDate: Date.now.addingTimeInterval(staleDuration)
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            lastSentProgress = contentState.progress
            lastSentStatus = contentState.status
            lastSentRemainingMinutes = contentState.remainingMinutes
        } catch {
            // Activity request failed — user may have denied permission
        }
    }

    public func update(contentState: PrinterAttributes.ContentState) async {
        let activities = Activity<PrinterAttributes>.activities
        guard let activity = activities.first else { return }

        // Deduplicate: skip if nothing meaningful changed
        if contentState.progress == lastSentProgress,
           contentState.status == lastSentStatus,
           contentState.remainingMinutes == lastSentRemainingMinutes
        {
            return
        }

        let content = ActivityContent(
            state: contentState,
            staleDate: Date.now.addingTimeInterval(staleDuration)
        )

        await activity.update(content)

        // End any extra activities that shouldn't exist (cleanup after app restart)
        for extra in activities.dropFirst() {
            await extra.end(content, dismissalPolicy: .immediate)
        }

        lastSentProgress = contentState.progress
        lastSentStatus = contentState.status
        lastSentRemainingMinutes = contentState.remainingMinutes
    }

    public func endIfNeeded(contentState: PrinterAttributes.ContentState) async {
        let activities = Activity<PrinterAttributes>.activities
        guard !activities.isEmpty else { return }

        let shouldEnd: Bool
        let dismissalPolicy: ActivityUIDismissalPolicy

        switch contentState.status {
        case .completed:
            shouldEnd = true
            dismissalPolicy = .after(Date.now.addingTimeInterval(completedDismissalDuration))
        case .cancelled:
            shouldEnd = true
            dismissalPolicy = .default
        case .idle:
            shouldEnd = true
            dismissalPolicy = .immediate
        case .preparing, .printing, .paused, .issue:
            shouldEnd = false
            dismissalPolicy = .default
        }

        guard shouldEnd else { return }

        let content = ActivityContent(
            state: contentState,
            staleDate: nil
        )

        // End ALL activities, not just the first
        for activity in activities {
            await activity.end(content, dismissalPolicy: dismissalPolicy)
        }

        lastSentProgress = nil
        lastSentStatus = nil
        lastSentRemainingMinutes = nil
    }
}

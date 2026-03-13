@testable import PandaModels
import Testing

@Suite("Preparation Stages")
struct PreparationStagesTests {
    // MARK: - Name Lookup

    @Test("Known stage returns name",
          arguments: [
              (1, "Auto bed leveling"),
              (7, "Heating hotend"),
              (35, "Paused: nozzle clog"),
              (77, "Preparing AMS"),
          ])
    func knownStageName(stgCur: Int, expected: String) {
        #expect(PreparationStages.name(for: stgCur) == expected)
    }

    @Test("Unknown stage number returns nil")
    func unknownStageName() {
        #expect(PreparationStages.name(for: 999) == nil)
        #expect(PreparationStages.name(for: -1) == nil)
    }

    // MARK: - Category Lookup

    @Test("Prepare stages", arguments: [1, 2, 3, 7, 13, 14])
    func prepareCategory(stgCur: Int) {
        #expect(PreparationStages.category(for: stgCur) == .prepare)
    }

    @Test("Calibrate stages", arguments: [8, 10, 12, 19])
    func calibrateCategory(stgCur: Int) {
        #expect(PreparationStages.category(for: stgCur) == .calibrate)
    }

    @Test("Paused stages", arguments: [5, 16, 30])
    func pausedCategory(stgCur: Int) {
        #expect(PreparationStages.category(for: stgCur) == .paused)
    }

    @Test("Filament stages", arguments: [4, 22, 24])
    func filamentCategory(stgCur: Int) {
        #expect(PreparationStages.category(for: stgCur) == .filament)
    }

    @Test("Issue stages", arguments: [6, 17, 20, 21, 23, 26, 27, 35])
    func issueCategory(stgCur: Int) {
        #expect(PreparationStages.category(for: stgCur) == .issue)
    }

    @Test("Unknown stage returns nil category")
    func unknownCategory() {
        #expect(PreparationStages.category(for: 999) == nil)
    }

    // MARK: - determineState

    @Test("FINISH returns completed")
    func finishState() {
        let (status, _) = PreparationStages.determineState(gcodeState: "FINISH", stgCur: 0, layerNum: 0)
        #expect(status == .completed)
    }

    @Test("COMPLETED returns completed")
    func completedState() {
        let (status, _) = PreparationStages.determineState(gcodeState: "COMPLETED", stgCur: 0, layerNum: 0)
        #expect(status == .completed)
    }

    @Test("CANCELLED returns cancelled")
    func cancelledState() {
        let (status, _) = PreparationStages.determineState(gcodeState: "CANCELLED", stgCur: 0, layerNum: 0)
        #expect(status == .cancelled)
    }

    @Test("FAILED returns cancelled")
    func failedState() {
        let (status, _) = PreparationStages.determineState(gcodeState: "FAILED", stgCur: 0, layerNum: 0)
        #expect(status == .cancelled)
    }

    @Test("PAUSE returns paused")
    func pauseState() {
        let (status, category) = PreparationStages.determineState(gcodeState: "PAUSE", stgCur: 5, layerNum: 0)
        #expect(status == .paused)
        #expect(category == "paused")
    }

    @Test("RUNNING with no active stage returns printing")
    func runningPrinting() {
        let (status, _) = PreparationStages.determineState(gcodeState: "RUNNING", stgCur: 0, layerNum: 100)
        #expect(status == .printing)
    }

    @Test("RUNNING with prepare stage and layerNum=0 returns preparing")
    func runningPreparing() {
        let (status, category) = PreparationStages.determineState(gcodeState: "RUNNING", stgCur: 1, layerNum: 0)
        #expect(status == .preparing)
        #expect(category == "prepare")
    }

    @Test("RUNNING with prepare stage and layerNum>=1 returns paused (mid-print)")
    func runningMidPrintInterruption() {
        let (status, category) = PreparationStages.determineState(gcodeState: "RUNNING", stgCur: 1, layerNum: 50)
        #expect(status == .paused)
        #expect(category == "prepare")
    }

    @Test("Issue stage returns issue")
    func issueState() {
        let (status, category) = PreparationStages.determineState(gcodeState: "RUNNING", stgCur: 35, layerNum: 0)
        #expect(status == .issue)
        #expect(category == "issue")
    }

    @Test("Unknown gcode state returns idle")
    func idleState() {
        let (status, _) = PreparationStages.determineState(gcodeState: "UNKNOWN", stgCur: 0, layerNum: 0)
        #expect(status == .idle)
    }

    @Test("PREPARE with calibrate stage returns preparing")
    func prepareCalibrate() {
        let (status, category) = PreparationStages.determineState(gcodeState: "PREPARE", stgCur: 8, layerNum: 0)
        #expect(status == .preparing)
        #expect(category == "calibrate")
    }
}

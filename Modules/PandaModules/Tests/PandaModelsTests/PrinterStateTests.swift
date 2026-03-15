@testable import PandaModels
import Testing

@Suite("Printer State")
struct PrinterStateTests {
    // MARK: - apply() Partial Updates

    @Test("apply() updates only present fields")
    func partialUpdate() {
        let state = PrinterState()
        state.progress = 10
        state.jobName = "OldJob"

        var payload = PandaMQTTPayload()
        payload.mcPercent = 50
        // jobName not set in payload

        state.apply(payload)

        #expect(state.progress == 50)
        #expect(state.jobName == "OldJob") // unchanged
    }

    @Test("apply() rounds temperature doubles to ints")
    func temperatureRounding() {
        let state = PrinterState()
        var payload = PandaMQTTPayload()
        payload.nozzleTemper = 220.7
        payload.bedTemper = 59.3

        state.apply(payload)

        #expect(state.nozzleTemp == 221)
        #expect(state.bedTemp == 59)
    }

    @Test("apply() sets lastUpdated when payload contains print data")
    func lastUpdatedWithPrintData() {
        let state = PrinterState()
        #expect(state.lastUpdated == nil)

        var payload = PandaMQTTPayload()
        payload.gcodeState = "IDLE"
        state.apply(payload)

        #expect(state.lastUpdated != nil)
    }

    @Test("apply() does not set lastUpdated for metadata-only payload")
    func lastUpdatedMetadataOnly() {
        let state = PrinterState()
        #expect(state.lastUpdated == nil)

        // Info messages only carry AMS module versions, no print data
        var payload = PandaMQTTPayload()
        payload.amsModuleVersions = [AMSModuleVersion(id: 0, hwVer: "AMS08")]
        state.apply(payload)

        #expect(state.lastUpdated == nil)
    }

    @Test("apply() always updates lastUpdated after initial data received")
    func lastUpdatedSubsequentMessages() throws {
        let state = PrinterState()

        // First message with print data sets lastUpdated
        var first = PandaMQTTPayload()
        first.nozzleTemper = 25.0
        state.apply(first)
        #expect(state.lastUpdated != nil)

        let firstTimestamp = try #require(state.lastUpdated)

        // Subsequent metadata-only message still updates timestamp
        var second = PandaMQTTPayload()
        second.amsModuleVersions = [AMSModuleVersion(id: 0, hwVer: "AMS08")]
        state.apply(second)
        #expect(try #require(state.lastUpdated) >= firstTimestamp)
    }

    @Test("apply() heatbreak fan ignores small changes")
    func heatbreakSmallChange() {
        let state = PrinterState()
        state.heatbreakFanSpeed = 200

        var payload = PandaMQTTPayload()
        payload.heatbreakFanSpeed = 210 // delta = 10, less than 26

        state.apply(payload)

        #expect(state.heatbreakFanSpeed == 200) // unchanged
    }

    @Test("apply() heatbreak fan accepts large changes")
    func heatbreakLargeChange() {
        let state = PrinterState()
        state.heatbreakFanSpeed = 200

        var payload = PandaMQTTPayload()
        payload.heatbreakFanSpeed = 100 // delta = 100, more than 26

        state.apply(payload)

        #expect(state.heatbreakFanSpeed == 100)
    }

    @Test("apply() heatbreak fan accepts any value when current is 0")
    func heatbreakFromZero() {
        let state = PrinterState()
        #expect(state.heatbreakFanSpeed == 0)

        var payload = PandaMQTTPayload()
        payload.heatbreakFanSpeed = 10

        state.apply(payload)

        #expect(state.heatbreakFanSpeed == 10)
    }

    // MARK: - contentState Conversion

    @Test("contentState maps all fields correctly")
    func contentStateMapping() {
        let state = PrinterState()
        state.gcodeState = "RUNNING"
        state.progress = 42
        state.remainingMinutes = 83
        state.jobName = "Benchy"
        state.layerNum = 150
        state.totalLayers = 300
        state.nozzleTemp = 220
        state.bedTemp = 60
        state.nozzleTargetTemp = 220
        state.bedTargetTemp = 60
        state.chamberTemp = 38

        let cs = state.contentState

        #expect(cs.status == .printing)
        #expect(cs.progress == 42)
        #expect(cs.remainingMinutes == 83)
        #expect(cs.jobName == "Benchy")
        #expect(cs.layerNum == 150)
        #expect(cs.totalLayers == 300)
        #expect(cs.nozzleTemp == 220)
        #expect(cs.bedTemp == 60)
        #expect(cs.nozzleTargetTemp == 220)
        #expect(cs.bedTargetTemp == 60)
        #expect(cs.chamberTemp == 38)
    }

    @Test("contentState default values produce idle status")
    func contentStateDefault() {
        let state = PrinterState()
        #expect(state.contentState.status == .idle)
    }

    @Test("contentState includes prepareStage from stgCur")
    func contentStatePrepareStage() {
        let state = PrinterState()
        state.gcodeState = "PREPARE"
        state.stgCur = 1

        let cs = state.contentState

        #expect(cs.status == .preparing)
        #expect(cs.prepareStage == "Auto bed leveling")
    }
}

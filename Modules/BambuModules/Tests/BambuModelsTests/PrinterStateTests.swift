@testable import BambuModels
import Testing

@Suite("Printer State")
struct PrinterStateTests {
    // MARK: - apply() Partial Updates

    @Test("apply() updates only present fields")
    func partialUpdate() {
        let state = PrinterState()
        state.progress = 10
        state.jobName = "OldJob"

        var payload = BambuMQTTPayload()
        payload.mcPercent = 50
        // jobName not set in payload

        state.apply(payload)

        #expect(state.progress == 50)
        #expect(state.jobName == "OldJob") // unchanged
    }

    @Test("apply() rounds temperature doubles to ints")
    func temperatureRounding() {
        let state = PrinterState()
        var payload = BambuMQTTPayload()
        payload.nozzleTemper = 220.7
        payload.bedTemper = 59.3

        state.apply(payload)

        #expect(state.nozzleTemp == 221)
        #expect(state.bedTemp == 59)
    }

    @Test("apply() updates lastUpdated")
    func lastUpdated() {
        let state = PrinterState()
        #expect(state.lastUpdated == nil)

        state.apply(BambuMQTTPayload())

        #expect(state.lastUpdated != nil)
    }

    @Test("apply() heatbreak fan ignores small changes")
    func heatbreakSmallChange() {
        let state = PrinterState()
        state.heatbreakFanSpeed = 200

        var payload = BambuMQTTPayload()
        payload.heatbreakFanSpeed = 210 // delta = 10, less than 26

        state.apply(payload)

        #expect(state.heatbreakFanSpeed == 200) // unchanged
    }

    @Test("apply() heatbreak fan accepts large changes")
    func heatbreakLargeChange() {
        let state = PrinterState()
        state.heatbreakFanSpeed = 200

        var payload = BambuMQTTPayload()
        payload.heatbreakFanSpeed = 100 // delta = 100, more than 26

        state.apply(payload)

        #expect(state.heatbreakFanSpeed == 100)
    }

    @Test("apply() heatbreak fan accepts any value when current is 0")
    func heatbreakFromZero() {
        let state = PrinterState()
        #expect(state.heatbreakFanSpeed == 0)

        var payload = BambuMQTTPayload()
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

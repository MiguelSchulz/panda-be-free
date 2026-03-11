@testable import BambuModels
import SFSafeSymbols
import SwiftUI
import Testing

@Suite("ContentState Computed Properties")
struct ContentStateTests {
    // MARK: - formattedTime

    @Test("formattedTime with 0 minutes")
    func formattedTimeZero() {
        let state = makeState(remainingMinutes: 0)
        #expect(String(localized: state.formattedTime) == "<1m")
    }

    @Test("formattedTime with minutes only")
    func formattedTimeMinutes() {
        let state = makeState(remainingMinutes: 45)
        #expect(String(localized: state.formattedTime) == "45m")
    }

    @Test("formattedTime with hours and minutes")
    func formattedTimeHours() {
        let state = makeState(remainingMinutes: 90)
        #expect(String(localized: state.formattedTime) == "1h 30m")
    }

    @Test("formattedTime with exact hours")
    func formattedTimeExactHours() {
        let state = makeState(remainingMinutes: 120)
        #expect(String(localized: state.formattedTime) == "2h 0m")
    }

    // MARK: - layerInfo

    @Test("layerInfo returns nil when totalLayers is 0")
    func layerInfoNil() {
        let state = makeState(totalLayers: 0)
        #expect(state.layerInfo == nil)
    }

    @Test("layerInfo returns current/total")
    func layerInfoFormat() {
        let state = makeState(layerNum: 150, totalLayers: 300)
        #expect(state.layerInfo == "150/300")
    }

    // MARK: - displayTitle

    @Test("displayTitle returns jobName when non-empty")
    func displayTitleJob() {
        let state = makeState(jobName: "Benchy")
        #expect(state.displayTitle == "Benchy")
    }

    @Test("displayTitle returns '3D Print' when empty")
    func displayTitleDefault() {
        let state = makeState(jobName: "")
        #expect(state.displayTitle == "3D Print")
    }

    // MARK: - temperatureInfo

    @Test("temperatureInfo returns nil when temps are nil")
    func temperatureInfoNil() {
        let state = makeState()
        #expect(state.temperatureInfo == nil)
    }

    @Test("temperatureInfo includes target when > 0")
    func temperatureInfoWithTarget() throws {
        let state = makeState(nozzleTemp: 200, bedTemp: 55, nozzleTargetTemp: 220, bedTargetTemp: 60)
        let info = state.temperatureInfo.map { String(localized: $0) }
        #expect(info != nil)
        #expect(try #require(info?.contains("200/220°C")))
        #expect(try #require(info?.contains("55/60°C")))
    }

    @Test("temperatureInfo includes chamber when > 0")
    func temperatureInfoChamber() throws {
        let state = makeState(nozzleTemp: 200, bedTemp: 55, chamberTemp: 38)
        let info = state.temperatureInfo.map { String(localized: $0) }
        #expect(info != nil)
        #expect(try #require(info?.contains("Chamber 38°C")))
    }

    // MARK: - stateLabel

    @Test("stateLabel maps statuses correctly",
          arguments: [
              (PrinterStatus.printing, nil as String?, "Printing"),
              (.completed, nil, "Complete"),
              (.cancelled, nil, "Cancelled"),
              (.idle, nil, "Idle"),
              (.issue, nil, "Issue"),
              (.preparing, nil, "Preparing"),
              (.preparing, "calibrate", "Calibrating"),
              (.paused, nil, "Paused"),
              (.paused, "filament", "Filament"),
          ])
    func stateLabel(status: PrinterStatus, category: String?, expected: String) {
        let state = makeState(status: status, stageCategory: category)
        #expect(String(localized: state.stateLabel) == expected)
    }

    // MARK: - prepareStageLabel

    @Test("prepareStageLabel returns stage for preparing/paused/issue")
    func prepareStageLabelShown() {
        for status in [PrinterStatus.preparing, .paused, .issue] {
            let state = makeState(status: status, prepareStage: "Auto bed leveling")
            #expect(state.prepareStageLabel == "Auto bed leveling")
        }
    }

    @Test("prepareStageLabel returns nil for printing/completed")
    func prepareStageLabelHidden() {
        for status in [PrinterStatus.printing, .completed, .cancelled, .idle] {
            let state = makeState(status: status, prepareStage: "Auto bed leveling")
            #expect(state.prepareStageLabel == nil)
        }
    }

    // MARK: - UI Helpers

    @Test("iconName returns correct symbols",
          arguments: [
              (PrinterStatus.completed, SFSymbol.checkmarkCircleFill),
              (.cancelled, .xmarkCircleFill),
              (.paused, .pauseCircleFill),
              (.issue, .exclamationmarkTriangleFill),
              (.printing, .printerFill),
          ])
    func iconName(status: PrinterStatus, expected: SFSymbol) {
        let state = makeState(status: status)
        #expect(state.iconName == expected)
    }

    @Test("trailingText returns correct text",
          arguments: [
              (PrinterStatus.completed, "Done"),
              (.cancelled, "Stop"),
              (.preparing, "..."),
              (.issue, "!"),
          ])
    func trailingText(status: PrinterStatus, expected: String) {
        let state = makeState(status: status)
        #expect(String(localized: state.trailingText) == expected)
    }

    @Test("trailingText shows percentage for printing/paused")
    func trailingTextPercent() {
        let state = makeState(progress: 42, status: .printing)
        #expect(String(localized: state.trailingText) == "42%")

        let pausedState = makeState(progress: 42, status: .paused)
        #expect(String(localized: pausedState.trailingText) == "42%")
    }

    // MARK: - compactTemperatureLines

    @Test("compactTemperatureLines includes nozzle with target")
    func compactTempLinesNozzle() {
        let state = makeState(nozzleTemp: 200, nozzleTargetTemp: 220)
        let lines = state.compactTemperatureLines
        let nozzleLine = lines.first { $0.id == "N" }
        #expect(nozzleLine?.text == "200/220")
    }

    @Test("compactTemperatureLines excludes chamber when nil")
    func compactTempLinesNoChamber() {
        let state = makeState(nozzleTemp: 200)
        let lines = state.compactTemperatureLines
        #expect(lines.first { $0.id == "C" } == nil)
    }

    @Test("compactTemperatureLines includes chamber when > 0")
    func compactTempLinesChamber() {
        let state = makeState(nozzleTemp: 200, chamberTemp: 38)
        let lines = state.compactTemperatureLines
        let chamberLine = lines.first { $0.id == "C" }
        #expect(chamberLine?.text == "38")
    }

    // MARK: - Helpers

    private func makeState(
        progress: Int = 0,
        remainingMinutes: Int = 0,
        jobName: String = "",
        layerNum: Int = 0,
        totalLayers: Int = 0,
        status: PrinterStatus = .idle,
        prepareStage: String? = nil,
        stageCategory: String? = nil,
        nozzleTemp: Int? = nil,
        bedTemp: Int? = nil,
        nozzleTargetTemp: Int? = nil,
        bedTargetTemp: Int? = nil,
        chamberTemp: Int? = nil
    ) -> PrinterAttributes.ContentState {
        PrinterAttributes.ContentState(
            progress: progress,
            remainingMinutes: remainingMinutes,
            jobName: jobName,
            layerNum: layerNum,
            totalLayers: totalLayers,
            status: status,
            prepareStage: prepareStage,
            stageCategory: stageCategory,
            nozzleTemp: nozzleTemp,
            bedTemp: bedTemp,
            nozzleTargetTemp: nozzleTargetTemp,
            bedTargetTemp: bedTargetTemp,
            chamberTemp: chamberTemp
        )
    }
}

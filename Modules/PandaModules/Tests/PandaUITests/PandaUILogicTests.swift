import PandaModels
@testable import PandaUI
import SFSafeSymbols
import SwiftUI
import Testing

@Suite("PandaUI Logic")
struct PandaUILogicTests {
    // MARK: - TemperatureGauge.gaugeColor

    @Test("gaugeColor green when ratio >= 0.95 (at target)")
    func gaugeColorGreen() {
        let gauge = TemperatureGauge(label: "Nozzle", icon: .flameFill,
                                     current: 220, target: 220, range: 0...300,
                                     editable: false) { _ in }
        #expect(gauge.gaugeColor == .green)
    }

    @Test("gaugeColor orange when ratio >= 0.5")
    func gaugeColorOrange() {
        let gauge = TemperatureGauge(label: "Nozzle", icon: .flameFill,
                                     current: 110, target: 220, range: 0...300,
                                     editable: false) { _ in }
        #expect(gauge.gaugeColor == .orange)
    }

    @Test("gaugeColor blue when ratio < 0.5")
    func gaugeColorBlue() {
        let gauge = TemperatureGauge(label: "Nozzle", icon: .flameFill,
                                     current: 50, target: 220, range: 0...300,
                                     editable: false) { _ in }
        #expect(gauge.gaugeColor == .blue)
    }

    @Test("gaugeColor orange when no target and current > 30")
    func gaugeColorNoTargetWarm() {
        let gauge = TemperatureGauge(label: "Chamber", icon: .wind,
                                     current: 38, target: nil, range: nil,
                                     editable: false) { _ in }
        #expect(gauge.gaugeColor == .orange)
    }

    @Test("gaugeColor blue when no target and current <= 30")
    func gaugeColorNoTargetCold() {
        let gauge = TemperatureGauge(label: "Chamber", icon: .wind,
                                     current: 25, target: nil, range: nil,
                                     editable: false) { _ in }
        #expect(gauge.gaugeColor == .blue)
    }

    @Test("gaugeColor treats target 0 as no target")
    func gaugeColorTargetZero() {
        let gauge = TemperatureGauge(label: "Nozzle", icon: .flameFill,
                                     current: 50, target: 0, range: 0...300,
                                     editable: false) { _ in }
        #expect(gauge.gaugeColor == .orange) // current > 30, no effective target
    }

    // MARK: - FanGauge.percent

    @Test("FanGauge percent conversion",
          arguments: [
              (0, 0),
              (128, 50),
              (255, 100),
              (1, 0),
          ])
    func fanGaugePercent(speed255: Int, expected: Int) {
        let gauge = FanGauge(label: "Part", speed255: speed255, editable: false) { _ in }
        #expect(gauge.percent == expected)
    }
}

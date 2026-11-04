import Foundation

/// Formats raw metric values for display and charts, honouring unit preferences.
struct MetricFormatter: Sendable {
    enum Style: Sendable {
        /// Value with its unit, e.g. `3h 24m`, `12.4 km`.
        case full
        /// Shorter value without unit, for tiles.
        case compact
        /// Bare number for chart axes.
        case axis
    }

    let units: UnitPreferences
    let locale: Locale

    init(units: UnitPreferences = .metric, locale: Locale = .autoupdatingCurrent) {
        self.units = units
        self.locale = locale
    }

    /// Value expressed in chart/display units: km/mi, m/ft, hours, counts.
    func plotValue(_ raw: Double, for metric: Metric) -> Double {
        switch metric {
        case .steps, .activityCount:
            return raw
        case .distance:
            return units.distanceUnit.value(fromMeters: raw)
        case .elevationGain:
            return units.elevationUnit.value(fromMeters: raw)
        case .exerciseDuration:
            return raw / 3_600
        }
    }

    func unitSymbol(for metric: Metric) -> String? {
        switch metric {
        case .steps, .activityCount:
            return nil
        case .distance:
            return units.distanceUnit.symbol
        case .elevationGain:
            return units.elevationUnit.symbol
        case .exerciseDuration:
            return nil
        }
    }

    func string(_ raw: Double, for metric: Metric, style: Style = .full) -> String {
        switch metric {
        case .steps:
            return stringForSteps(raw, style: style)
        case .activityCount:
            return stringForCount(raw)
        case .distance:
            return stringForDistance(raw, style: style)
        case .elevationGain:
            return stringForElevation(raw, style: style)
        case .exerciseDuration:
            return stringForDuration(raw, style: style)
        }
    }

    /// Axis tick label for an already-converted plot value.
    func axisLabel(_ plotValue: Double, for metric: Metric) -> String {
        switch metric {
        case .steps, .activityCount:
            return compactNumber(plotValue)
        case .distance:
            return decimal(plotValue, digits: plotValue < 10 ? 1 : 0)
        case .elevationGain:
            return integer(plotValue)
        case .exerciseDuration:
            if plotValue >= 1 {
                return integer(plotValue.rounded()) + "h"
            }
            return integer((plotValue * 60).rounded()) + "m"
        }
    }

    /// Large number for the hero card; the unit is rendered separately.
    func heroString(_ raw: Double, for metric: Metric) -> String {
        switch metric {
        case .steps, .activityCount:
            return integer(raw)
        case .distance:
            return decimal(units.distanceUnit.value(fromMeters: raw), digits: 1)
        case .elevationGain:
            return integer(units.elevationUnit.value(fromMeters: raw))
        case .exerciseDuration:
            return stringForDuration(raw, style: .full)
        }
    }

    func heroUnit(for metric: Metric) -> String? {
        switch metric {
        case .steps: return "steps"
        case .activityCount: return "activities"
        case .distance: return units.distanceUnit.symbol
        case .elevationGain: return units.elevationUnit.symbol
        case .exerciseDuration: return nil
        }
    }

    /// Compact value for the metric tiles.
    func tileString(_ raw: Double, for metric: Metric) -> String {
        switch metric {
        case .steps:
            return compactNumber(raw)
        case .activityCount:
            return integer(raw)
        case .distance:
            return decimal(units.distanceUnit.value(fromMeters: raw), digits: 1) + " " + units.distanceUnit.symbol
        case .elevationGain:
            return integer(units.elevationUnit.value(fromMeters: raw)) + " " + units.elevationUnit.symbol
        case .exerciseDuration:
            return stringForDuration(raw, style: .full)
        }
    }

    /// Pace as minutes and seconds per distance unit, e.g. `5:42 /km`.
    func pace(_ secondsPerUnit: TimeInterval, unit: DistanceUnit) -> String {
        let total = max(0, secondsPerUnit)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        return String(format: "%d:%02d /%@", minutes, seconds, unit.symbol)
    }

    func heartRate(_ beatsPerMinute: Double) -> String {
        integer(beatsPerMinute.rounded()) + " bpm"
    }

    /// "1 km" or "1 mi", plus "0.6 km" for a partial split.
    func splitDistance(_ value: Double, unit: DistanceUnit) -> String {
        if abs(value - 1) < 0.02 {
            return "1 \(unit.symbol)"
        }
        return decimal(value, digits: 1) + " " + unit.symbol
    }

    func duration(minutes: Double) -> String {
        stringForDuration(minutes * 60, style: .full)
    }

    // MARK: - Private

    private func stringForSteps(_ value: Double, style: Style) -> String {
        switch style {
        case .full: return integer(value) + " steps"
        case .compact: return compactNumber(value)
        case .axis: return compactNumber(value)
        }
    }

    private func stringForCount(_ value: Double) -> String {
        let count = Int(value.rounded())
        let noun = count == 1 ? "activity" : "activities"
        return "\(integer(value)) \(noun)"
    }

    private func stringForDistance(_ meters: Double, style: Style) -> String {
        let value = units.distanceUnit.value(fromMeters: meters)
        let symbol = units.distanceUnit.symbol
        switch style {
        case .full:
            let digits = value < 10 && value > 0 ? 2 : 1
            return "\(decimal(value, digits: digits)) \(symbol)"
        case .compact:
            return decimal(value, digits: 1)
        case .axis:
            return decimal(value, digits: value < 10 ? 1 : 0)
        }
    }

    private func stringForElevation(_ meters: Double, style: Style) -> String {
        let value = units.elevationUnit.value(fromMeters: meters)
        let symbol = units.elevationUnit.symbol
        switch style {
        case .full: return "\(integer(value)) \(symbol)"
        case .compact: return integer(value)
        case .axis: return integer(value)
        }
    }

    private func stringForDuration(_ seconds: TimeInterval, style: Style) -> String {
        let totalMinutes = Int((max(0, seconds) / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch style {
        case .full:
            if hours == 0 { return "\(minutes)m" }
            if minutes == 0 { return "\(hours)h" }
            return "\(hours)h \(minutes)m"
        case .compact:
            if hours == 0 { return "\(minutes)m" }
            if minutes == 0 { return "\(hours)h" }
            return "\(hours)h \(minutes)m"
        case .axis:
            return hours > 0 ? "\(hours)h" : "\(minutes)m"
        }
    }

    private func integer(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(locale))
    }

    private func decimal(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(locale))
    }

    private func compactNumber(_ value: Double) -> String {
        value.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
                .locale(locale)
        )
    }
}

import Foundation
import Testing
@testable import StatsWorkout

@Suite("Formatting")
struct MetricFormatterTests {
    private let formatter = MetricFormatter(units: .metric, locale: Locale(identifier: "en_US"))
    private let imperial = MetricFormatter(units: .imperial, locale: Locale(identifier: "en_US"))

    @Test("Steps are grouped and counted")
    func steps() {
        #expect(formatter.string(12_345, for: .steps) == "12,345 steps")
        #expect(formatter.heroString(12_345, for: .steps) == "12,345")
        #expect(formatter.heroUnit(for: .steps) == "steps")
        #expect(formatter.unitSymbol(for: .steps) == nil)
    }

    @Test("Distance converts between kilometres and miles")
    func distance() {
        #expect(formatter.plotValue(1_500, for: .distance) == 1.5)
        #expect(formatter.string(1_500, for: .distance) == "1.50 km")
        #expect(imperial.plotValue(1_609.344, for: .distance) == 1.0)
        #expect(imperial.string(1_609.344, for: .distance) == "1.00 mi")
        #expect(formatter.tileString(42_400, for: .distance) == "42.4 km")
    }

    @Test("Elevation converts to feet")
    func elevation() {
        #expect(formatter.string(820, for: .elevationGain) == "820 m")
        #expect(imperial.string(100, for: .elevationGain) == "328 ft")
        #expect(imperial.tileString(100, for: .elevationGain) == "328 ft")
    }

    @Test("Duration is shown in hours and minutes")
    func duration() {
        #expect(formatter.string(3_660, for: .exerciseDuration) == "1h 1m")
        #expect(formatter.string(3_600, for: .exerciseDuration) == "1h")
        #expect(formatter.string(540, for: .exerciseDuration) == "9m")
        #expect(formatter.plotValue(5_400, for: .exerciseDuration) == 1.5)
    }

    @Test("Axis labels stay short")
    func axisLabels() {
        #expect(formatter.axisLabel(12_000, for: .steps).lowercased().hasPrefix("12"))
        #expect(formatter.axisLabel(2.5, for: .distance).hasPrefix("2"))
        #expect(formatter.axisLabel(1.5, for: .exerciseDuration) == "2h")
        #expect(formatter.axisLabel(0.25, for: .exerciseDuration) == "15m")
    }

    @Test("Activity counts are pluralised")
    func activityCount() {
        #expect(formatter.string(1, for: .activityCount) == "1 activity")
        #expect(formatter.string(4, for: .activityCount) == "4 activities")
    }
}

@Suite("Period formatting")
struct PeriodFormatterTests {
    private let calendar = TestSupport.calendar()
    private var formatter: PeriodFormatter {
        PeriodFormatter(calendar: calendar, locale: Locale(identifier: "en_US"))
    }
    private var period: PeriodCalendar { TestSupport.period(calendar) }

    @Test("Range titles")
    func rangeTitles() {
        let month = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 14))
        #expect(formatter.rangeTitle(for: month) == "November 2026")

        let quarter = period.range(for: .quarter, containing: TestSupport.date(calendar, 2026, 11, 14))
        #expect(formatter.rangeTitle(for: quarter) == "Q4 2026")

        let year = period.range(for: .year, containing: TestSupport.date(calendar, 2026, 11, 14))
        #expect(formatter.rangeTitle(for: year) == "2026")

        let week = period.range(for: .week, containing: TestSupport.date(calendar, 2026, 11, 4))
        #expect(formatter.rangeTitle(for: week) == "Nov 2\u{2009}–\u{2009}8, 2026")
    }
}

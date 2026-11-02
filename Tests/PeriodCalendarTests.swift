import Foundation
import Testing
@testable import StatsWorkout

@Suite("Period calendar")
struct PeriodCalendarTests {
    private let calendar = TestSupport.calendar()
    private var period: PeriodCalendar { TestSupport.period(calendar) }

    @Test("Month range covers the whole calendar month")
    func monthRange() {
        let mid = TestSupport.date(calendar, 2026, 11, 14, 9, 30)
        let range = period.range(for: .month, containing: mid)

        #expect(range.start == TestSupport.date(calendar, 2026, 11, 1))
        #expect(range.end == TestSupport.date(calendar, 2026, 12, 1))
        #expect(range.kind == .month)
    }

    @Test("Stepping a month backwards handles month lengths")
    func monthStepping() {
        let november = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 14))
        let october = period.offset(november, by: -1)

        #expect(october.start == TestSupport.date(calendar, 2026, 10, 1))
        #expect(october.end == TestSupport.date(calendar, 2026, 11, 1))

        let december = period.offset(november, by: 1)
        #expect(december.start == TestSupport.date(calendar, 2026, 12, 1))
        #expect(december.end == TestSupport.date(calendar, 2027, 1, 1))
    }

    @Test("Quarter boundaries follow calendar quarters")
    func quarterRange() {
        let range = period.range(for: .quarter, containing: TestSupport.date(calendar, 2026, 11, 14))

        #expect(range.start == TestSupport.date(calendar, 2026, 10, 1))
        #expect(range.end == TestSupport.date(calendar, 2027, 1, 1))

        let previous = period.offset(range, by: -1)
        #expect(previous.start == TestSupport.date(calendar, 2026, 7, 1))
        #expect(previous.end == TestSupport.date(calendar, 2026, 10, 1))
    }

    @Test("Year and week ranges use the configured first weekday")
    func yearAndWeekRanges() {
        let year = period.range(for: .year, containing: TestSupport.date(calendar, 2026, 6, 1))
        #expect(year.start == TestSupport.date(calendar, 2026, 1, 1))
        #expect(year.end == TestSupport.date(calendar, 2027, 1, 1))

        // 2026-11-02 is a Monday.
        let week = period.range(for: .week, containing: TestSupport.date(calendar, 2026, 11, 4))
        #expect(week.start == TestSupport.date(calendar, 2026, 11, 2))
        #expect(week.end == TestSupport.date(calendar, 2026, 11, 9))
    }

    @Test("Bucket counts match the period")
    func bucketCounts() {
        let month = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 14))
        #expect(period.buckets(for: month).count == 30)
        #expect(period.granularity(for: month) == .day)

        let quarter = period.range(for: .quarter, containing: TestSupport.date(calendar, 2026, 11, 14))
        #expect(period.buckets(for: quarter).count == 14)
        #expect(period.granularity(for: quarter) == .week)

        let year = period.range(for: .year, containing: TestSupport.date(calendar, 2026, 6, 1))
        #expect(period.buckets(for: year).count == 12)
        #expect(period.granularity(for: year) == .month)
    }

    @Test("Custom ranges pick a sensible granularity")
    func customGranularity() {
        let short = period.customRange(
            start: TestSupport.date(calendar, 2026, 11, 1),
            end: TestSupport.date(calendar, 2026, 11, 10)
        )
        #expect(period.granularity(for: short) == .day)
        #expect(period.buckets(for: short).count == 10)

        let medium = period.customRange(
            start: TestSupport.date(calendar, 2026, 1, 1),
            end: TestSupport.date(calendar, 2026, 4, 10)
        )
        #expect(period.granularity(for: medium) == .week)

        let long = period.customRange(
            start: TestSupport.date(calendar, 2025, 1, 1),
            end: TestSupport.date(calendar, 2026, 6, 1)
        )
        #expect(period.granularity(for: long) == .month)
    }

    @Test("Buckets survive a daylight-saving transition")
    func daylightSavingTransition() {
        let prague = TestSupport.calendar(timeZone: "Europe/Prague")
        let period = TestSupport.period(prague)
        let march = period.range(for: .month, containing: TestSupport.date(prague, 2026, 3, 15))
        let buckets = period.buckets(for: march)

        #expect(buckets.count == 31)
        #expect(buckets.allSatisfy { $0.end > $0.start })
        #expect(buckets.last?.end == march.end)
    }

    @Test("Bucket lookup finds the containing bucket")
    func bucketLookup() {
        let range = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 14))
        let buckets = period.buckets(for: range)

        #expect(period.bucketIndex(containing: range.start, in: buckets) == 0)
        #expect(period.bucketIndex(containing: TestSupport.date(calendar, 2026, 11, 15, 13), in: buckets) == 14)
        #expect(period.bucketIndex(containing: range.end, in: buckets) == nil)
        #expect(period.bucketIndex(containing: TestSupport.date(calendar, 2026, 10, 31, 23), in: buckets) == nil)
    }

    @Test("Comparison ranges support previous period and last year")
    func comparisonRanges() {
        let range = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 14))

        let previous = period.comparisonRange(for: range, mode: .previousPeriod)
        #expect(previous.start == TestSupport.date(calendar, 2026, 10, 1))
        #expect(previous.end == TestSupport.date(calendar, 2026, 11, 1))

        let lastYear = period.comparisonRange(for: range, mode: .samePeriodLastYear)
        #expect(lastYear.start == TestSupport.date(calendar, 2025, 11, 1))
        #expect(lastYear.end == TestSupport.date(calendar, 2025, 12, 1))
    }

    @Test("Elapsed fraction is clamped")
    func elapsedFraction() {
        let range = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 1))
        #expect(period.elapsedFraction(of: range, at: TestSupport.date(calendar, 2026, 10, 1)) == 0)
        #expect(period.elapsedFraction(of: range, at: TestSupport.date(calendar, 2026, 12, 15)) == 1)
        #expect(period.elapsedFraction(of: range, at: range.start) == 0)
    }
}

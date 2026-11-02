#if DEBUG
import Foundation

/// Deterministic sample statistics used by SwiftUI previews.
enum PreviewStats {
    static func sample(kind: PeriodKind = .month, now: Date = Date()) -> PeriodStats {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let periodCalendar = PeriodCalendar(calendar: calendar)
        let range = periodCalendar.range(for: kind, containing: now)
        let previousRange = periodCalendar.offset(range, by: -1)
        let window = DateInterval(start: previousRange.start, end: range.end)

        let activities = MockHealthData.activities(in: window, calendar: calendar, seed: 0x5EED, now: now)
        let steps = MockHealthData.dailySteps(in: window, calendar: calendar, seed: 0x5EED, now: now)

        return StatsAggregator(periodCalendar: periodCalendar).stats(
            for: range,
            activities: activities,
            steps: steps,
            now: now
        )
    }
}
#endif

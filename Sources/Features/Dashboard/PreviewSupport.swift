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
        let distance = MockHealthData.distanceSamples(
            in: window, granularity: .day, calendar: calendar, seed: 0x5EED, now: now
        )
        let elevation = MockHealthData.elevationSamples(
            in: window, granularity: .day, calendar: calendar, seed: 0x5EED, now: now
        )

        let windows = activities.map { DateInterval(start: $0.start, end: $0.end) }
        let samples = HealthSamples(
            activities: activities,
            steps: steps,
            distance: distance,
            elevation: elevation,
            workoutSteps: MockHealthData.workoutQuantitySamples(
                in: window, kind: .steps, within: windows,
                granularity: .day, calendar: calendar, seed: 0x5EED, now: now
            ),
            workoutDistance: MockHealthData.workoutQuantitySamples(
                in: window, kind: .distance, within: windows,
                granularity: .day, calendar: calendar, seed: 0x5EED, now: now
            )
        )

        return StatsAggregator(periodCalendar: periodCalendar).stats(
            for: range,
            samples: samples,
            now: now
        ).allData
    }
}
#endif

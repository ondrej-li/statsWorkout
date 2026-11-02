import Foundation

/// Calendar arithmetic for week / month / quarter / year / custom windows.
///
/// Deliberately free of HealthKit and SwiftUI so it can be unit-tested with a
/// fixed `Calendar` and time zone.
struct PeriodCalendar: Sendable, Equatable {
    var calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    // MARK: - Ranges

    func range(for kind: PeriodKind, containing date: Date) -> PeriodRange {
        switch kind {
        case .last24Hours:
            return makeRange(kind: .last24Hours, interval: rollingDayInterval(endingAt: date), fallback: date)
        case .day:
            return makeRange(kind: .day, interval: calendar.dateInterval(of: .day, for: date), fallback: date)
        case .week:
            return makeRange(kind: .week, interval: calendar.dateInterval(of: .weekOfYear, for: date), fallback: date)
        case .month:
            return makeRange(kind: .month, interval: calendar.dateInterval(of: .month, for: date), fallback: date)
        case .year:
            return makeRange(kind: .year, interval: calendar.dateInterval(of: .year, for: date), fallback: date)
        case .quarter:
            let yearStart = calendar.dateInterval(of: .year, for: date)?.start ?? calendar.startOfDay(for: date)
            let monthIndex = calendar.component(.month, from: date) - 1
            let quarterOffset = (monthIndex / 3) * 3
            let start = calendar.date(byAdding: .month, value: quarterOffset, to: yearStart) ?? yearStart
            let end = calendar.date(byAdding: .month, value: 3, to: start) ?? start
            return PeriodRange(kind: .quarter, start: start, end: end)
        case .custom:
            let startOfDay = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return PeriodRange(kind: .custom, start: startOfDay, end: end)
        }
    }

    func customRange(start: Date, end: Date) -> PeriodRange {
        let normalizedStart = calendar.startOfDay(for: min(start, end))
        let lastDay = calendar.startOfDay(for: max(start, end))
        let normalizedEnd = max(
            calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay,
            calendar.date(byAdding: .day, value: 1, to: normalizedStart) ?? normalizedStart
        )
        return PeriodRange(kind: .custom, start: normalizedStart, end: normalizedEnd)
    }

    func offset(_ range: PeriodRange, by value: Int) -> PeriodRange {
        guard value != 0 else { return range }

        switch range.kind {
        case .custom:
            let days = max(1, range.dayCount(in: calendar))
            let shift = value * days
            let start = calendar.date(byAdding: .day, value: shift, to: range.start) ?? range.start
            let end = calendar.date(byAdding: .day, value: shift, to: range.end) ?? range.end
            return PeriodRange(kind: .custom, start: start, end: end)
        case .day:
            let anchor = calendar.date(byAdding: .day, value: value, to: range.start) ?? range.start
            return self.range(for: .day, containing: anchor)
        case .last24Hours:
            let shift = Double(value) * 24 * 60 * 60
            return PeriodRange(
                kind: .last24Hours,
                start: range.start.addingTimeInterval(shift),
                end: range.end.addingTimeInterval(shift)
            )
        case .week, .month, .quarter, .year:
            let anchor = calendar.date(byAdding: component(for: range.kind), value: value, to: range.start) ?? range.start
            return self.range(for: range.kind, containing: anchor)
        }
    }

    func comparisonRange(for range: PeriodRange, mode: ComparisonMode) -> PeriodRange {
        switch mode {
        case .previousPeriod:
            return offset(range, by: -1)
        case .samePeriodLastYear:
            let start = calendar.date(byAdding: .year, value: -1, to: range.start) ?? range.start
            let end = calendar.date(byAdding: .year, value: -1, to: range.end) ?? range.end
            return PeriodRange(kind: range.kind, start: start, end: end)
        }
    }

    // MARK: - Buckets

    func granularity(for range: PeriodRange) -> BucketGranularity {
        switch range.kind {
        case .last24Hours, .day:
            return .hour
        case .week, .month:
            return .day
        case .quarter:
            return .week
        case .year:
            return .month
        case .custom:
            let days = range.dayCount(in: calendar)
            if days <= 2 { return .hour }
            if days <= 45 { return .day }
            if days <= 200 { return .week }
            return .month
        }
    }

    func buckets(for range: PeriodRange) -> [Bucket] {
        let granularity = granularity(for: range)
        let step: Calendar.Component
        switch granularity {
        case .hour: step = .hour
        case .day: step = .day
        case .week: step = .weekOfYear
        case .month: step = .month
        }

        var buckets: [Bucket] = []
        var cursor = range.start
        var index = 0

        while cursor < range.end, index < 500 {
            let next = calendar.date(byAdding: step, value: 1, to: cursor) ?? range.end
            let bucketEnd = min(next, range.end)
            buckets.append(Bucket(index: index, start: cursor, end: bucketEnd))
            cursor = next
            index += 1
        }

        return buckets
    }

    /// Index of the bucket containing `date`, or `nil` when outside the range.
    func bucketIndex(containing date: Date, in buckets: [Bucket]) -> Int? {
        guard let last = buckets.last, date >= buckets[0].start, date < last.end else { return nil }
        var low = 0
        var high = buckets.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let bucket = buckets[mid]
            if date < bucket.start {
                high = mid - 1
            } else if date >= bucket.end {
                low = mid + 1
            } else {
                return bucket.index
            }
        }
        return nil
    }

    // MARK: - Elapsed time

    func isCurrent(_ range: PeriodRange, at now: Date) -> Bool {
        range.contains(now)
    }

    func elapsedFraction(of range: PeriodRange, at now: Date) -> Double {
        guard range.duration > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(range.start)
        return min(max(elapsed / range.duration, 0), 1)
    }

    /// Number of buckets that have started at `now` (at least 1).
    func elapsedBucketCount(in buckets: [Bucket], at now: Date) -> Int {
        let started = buckets.filter { $0.start <= now }.count
        return max(1, min(started, buckets.count))
    }

    // MARK: - Helpers

    private func component(for kind: PeriodKind) -> Calendar.Component {
        switch kind {
        case .last24Hours, .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .quarter: return .month
        case .year: return .year
        case .custom: return .day
        }
    }

    /// Rolling 24-hour window aligned to the hour boundary that contains `date`,
    /// so the buckets line up with clock hours.
    private func rollingDayInterval(endingAt date: Date) -> DateInterval {
        let hour = calendar.dateInterval(of: .hour, for: date)
        let end = hour?.end ?? date
        let start = calendar.date(byAdding: .hour, value: -24, to: end) ?? end.addingTimeInterval(-86_400)
        return DateInterval(start: start, end: end)
    }

    private func makeRange(kind: PeriodKind, interval: DateInterval?, fallback date: Date) -> PeriodRange {
        if let interval {
            return PeriodRange(kind: kind, start: interval.start, end: interval.end)
        }
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return PeriodRange(kind: kind, start: start, end: end)
    }
}

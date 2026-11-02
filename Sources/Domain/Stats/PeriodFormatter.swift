import Foundation

/// Human-readable labels for ranges, buckets and progress captions.
struct PeriodFormatter: Sendable {
    let calendar: Calendar
    let locale: Locale

    init(calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) {
        self.calendar = calendar
        self.locale = locale
    }

    func rangeTitle(for range: PeriodRange) -> String {
        switch range.kind {
        case .last24Hours:
            return "Last 24 hours"
        case .day:
            return text(range.start, .dateTime.weekday(.wide).day().month(.abbreviated))
        case .week:
            return spanTitle(from: range.start, to: range.end)
        case .month:
            return text(range.start, .dateTime.month(.wide).year())
        case .quarter:
            let month = calendar.component(.month, from: range.start)
            let quarter = ((month - 1) / 3) + 1
            let year = calendar.component(.year, from: range.start)
            return "Q\(quarter) \(year)"
        case .year:
            return text(range.start, .dateTime.year())
        case .custom:
            return spanTitle(from: range.start, to: range.end)
        }
    }

    /// Locale-aware span, e.g. `Nov 2 – 8, 2026` or `Oct 29 – Nov 4, 2026`.
    func spanTitle(from start: Date, to end: Date) -> String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: end) ?? end
        let range = start..<max(start, lastDay)
        return Date.IntervalFormatStyle(date: .omitted, time: .omitted)
            .day()
            .month(.abbreviated)
            .year()
            .locale(locale)
            .format(range)
    }

    func bucketAxisLabel(for bucket: Bucket, in stats: PeriodStats) -> String {
        switch stats.granularity {
        case .hour:
            return text(bucket.start, .dateTime.hour())
        case .day:
            if stats.range.kind == .week {
                return text(bucket.start, .dateTime.weekday(.abbreviated))
            }
            return text(bucket.start, .dateTime.day())
        case .week:
            return text(bucket.start, .dateTime.day().month(.abbreviated))
        case .month:
            return text(bucket.start, .dateTime.month(.abbreviated))
        }
    }

    func bucketTitle(for bucket: Bucket, in stats: PeriodStats) -> String {
        switch stats.granularity {
        case .hour:
            let from = text(bucket.start, .dateTime.hour().minute())
            let to = text(bucket.end, .dateTime.hour().minute())
            return "\(from) – \(to)"
        case .day:
            return text(bucket.start, .dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .week:
            return "Week of " + text(bucket.start, .dateTime.day().month(.abbreviated))
        case .month:
            return text(bucket.start, .dateTime.month(.wide).year())
        }
    }

    /// Compact bucket label for summary captions, e.g. `1 Nov` or `Nov`.
    func shortBucketTitle(for bucket: Bucket, in stats: PeriodStats) -> String {
        switch stats.granularity {
        case .hour:
            return text(bucket.start, .dateTime.hour().minute())
        case .day:
            return text(bucket.start, .dateTime.day().month(.abbreviated))
        case .week:
            return text(bucket.start, .dateTime.day().month(.abbreviated))
        case .month:
            return text(bucket.start, .dateTime.month(.abbreviated))
        }
    }

    /// "Day 12 of 30", "Week 5 of 13", "Month 4 of 12" or "Complete".
    func progressCaption(for stats: PeriodStats) -> String {
        guard stats.isCurrentPeriod else { return "Complete" }
        switch stats.granularity {
        case .hour:
            return "Hour \(stats.elapsedBucketCount) of \(stats.buckets.count)"
        case .day:
            return "Day \(stats.elapsedBucketCount) of \(stats.buckets.count)"
        case .week:
            return "Week \(stats.elapsedBucketCount) of \(stats.buckets.count)"
        case .month:
            return "Month \(stats.elapsedBucketCount) of \(stats.buckets.count)"
        }
    }

    /// Noun for one bucket, e.g. "hour", used in labels like "Average per hour".
    func bucketNoun(for stats: PeriodStats) -> String {
        switch stats.granularity {
        case .hour: return "hour"
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        }
    }

    func comparisonCaption(for stats: PeriodStats) -> String {
        switch stats.comparisonMode {
        case .previousPeriod: return "vs previous period"
        case .samePeriodLastYear: return "vs same period last year"
        }
    }

    private func text(_ date: Date, _ style: Date.FormatStyle) -> String {
        date.formatted(style.locale(locale))
    }
}

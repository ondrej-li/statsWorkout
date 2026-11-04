import Foundation

/// Time windows a user can summarise statistics over.
enum PeriodKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case last24Hours
    case day
    case week
    case month
    case quarter
    case year
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last24Hours: return L10n.t(.period24h)
        case .day: return L10n.t(.periodDay)
        case .week: return L10n.t(.periodWeek)
        case .month: return L10n.t(.periodMonth)
        case .quarter: return L10n.t(.periodQuarter)
        case .year: return L10n.t(.periodYear)
        case .custom: return L10n.t(.periodCustom)
        }
    }

    /// Periods that can be stepped forward/backward with the chevrons.
    var isNavigable: Bool { self != .custom }
}

/// Resolution of the bars/points drawn for a period.
enum BucketGranularity: String, Sendable, Hashable, CaseIterable {
    case hour
    case day
    case week
    case month
}

/// How the current period is compared against history.
enum ComparisonMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case previousPeriod
    case samePeriodLastYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .previousPeriod: return L10n.t(.comparisonPrevious)
        case .samePeriodLastYear: return L10n.t(.comparisonLastYear)
        }
    }
}

/// A half-open date range (`start..<end`) with the period it was derived from.
struct PeriodRange: Hashable, Sendable, Codable {
    var kind: PeriodKind
    var start: Date
    var end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var interval: DateInterval { DateInterval(start: start, end: end) }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    func dayCount(in calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

/// One bar (or point) on the charts.
struct Bucket: Hashable, Sendable, Identifiable {
    let index: Int
    let start: Date
    let end: Date

    var id: Int { index }
    var duration: TimeInterval { end.timeIntervalSince(start) }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

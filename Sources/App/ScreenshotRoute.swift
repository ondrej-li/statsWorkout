import Foundation

/// Launch arguments that put the app on a specific screen, so the App Store
/// artwork can be captured from a clean simulator (see `make shots`).
///
/// Every value here is `nil` in a Release build, so none of it can reach the
/// archive shipped to the App Store — the flags only exist to photograph screens
/// that would otherwise need a finger on the glass.
enum ScreenshotRoute {
    enum Tab: String {
        case stats
        case activities
        case settings
    }

    /// Tab to open at launch.
    static var tab: Tab? {
        value(after: "-screenshotTab").flatMap(Tab.init(rawValue:))
    }

    /// Period chip to select, e.g. `day` or `month`.
    static var period: PeriodKind? {
        value(after: "-screenshotPeriod").flatMap(PeriodKind.init(rawValue:))
    }

    /// Data scope to select: `all` or `activities`.
    static var scope: DataScope? {
        value(after: "-screenshotScope").flatMap(DataScope.init(rawValue:))
    }

    /// Metric to highlight, so the charts draw that metric.
    static var metric: Metric? {
        value(after: "-screenshotMetric").flatMap(Metric.init(rawValue:))
    }

    /// Section to scroll to: `charts`, `progress` or `activities`.
    static var section: String? {
        value(after: "-screenshotSection")
    }

    /// Periods to step back at launch, so the shots show a complete month or day
    /// instead of the few days elapsed so far.
    static var periodOffset: Int {
        value(after: "-screenshotOffset").flatMap(Int.init) ?? 0
    }

    /// Bucket index to select, or `peak` for the highest bucket of the shown
    /// metric — so a callout never lands on an empty bar.
    enum Selection {
        case index(Int)
        case peak
    }

    static var selection: Selection? {
        guard let raw = value(after: "-screenshotSelect") else { return nil }
        if raw == "peak" { return .peak }
        return Int(raw).map(Selection.index)
    }

    /// Frozen clock, so a shot can show a whole day rather than the hours
    /// elapsed so far. ISO 8601, e.g. `2026-11-02T23:30:00`.
    static var now: Date? {
        guard let raw = value(after: "-screenshotNow") else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime,
                                   .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter.date(from: raw)
    }

    /// Delay before the frame is taken is handled by the Makefile; this only
    /// controls what the app shows.
    static var isActive: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-screenshotTab")
            || ProcessInfo.processInfo.arguments.contains("-screenshotSection")
        #else
        false
        #endif
    }

    private static func value(after flag: String) -> String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        let value = arguments[index + 1]
        // Negative numbers (e.g. `-screenshotOffset -1`) are values, not flags.
        if value.hasPrefix("-"), Int(value) == nil, Double(value) == nil { return nil }
        return value
        #else
        nil
        #endif
    }
}

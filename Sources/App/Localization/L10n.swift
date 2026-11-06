import Foundation

/// Keys for every user-facing string. The raw value is the key in the JSON
/// resource, so a typo shows up as a missing translation rather than a crash.
enum L10nKey: String, CaseIterable, Sendable {
    // Tabs and common actions
    case tabStats = "tab.stats"
    case tabActivities = "tab.activities"
    case tabSettings = "tab.settings"
    case actionToday = "action.today"
    case actionRetry = "action.retry"
    case actionReload = "action.reload"
    case actionCancel = "action.cancel"
    case actionApply = "action.apply"
    case actionDone = "action.done"
    case actionPreviousPeriod = "action.previousPeriod"
    case actionNextPeriod = "action.nextPeriod"
    case actionRequesting = "action.requesting"
    case actionAllowAccess = "action.allowAccess"

    // Demo data labelling
    case demoBadge = "demo.badge"
    case demoBadgeA11y = "demo.badge.a11y"
    case demoBanner = "demo.banner"
    case demoLogFooter = "demo.log.footer"
    case demoRouteSource = "demo.route.source"

    // Custom range sheet
    case rangeTitle = "range.title"
    case rangeFrom = "range.from"
    case rangeTo = "range.to"
    case rangeStart = "range.start"
    case rangeEnd = "range.end"

    // Periods
    case period24h = "period.24h"
    case periodDay = "period.day"
    case periodWeek = "period.week"
    case periodMonth = "period.month"
    case periodQuarter = "period.quarter"
    case periodYear = "period.year"
    case periodCustom = "period.custom"
    case periodLast24Hours = "period.last24Hours"
    case periodComplete = "period.complete"
    case periodProgressDay = "period.progress.day"
    case periodProgressWeek = "period.progress.week"
    case periodProgressMonth = "period.progress.month"
    case periodProgressHour = "period.progress.hour"
    case periodBucketWeek = "period.bucket.week"

    // Metrics
    case metricSteps = "metric.steps"
    case metricStepsSubtitle = "metric.steps.subtitle"
    case metricDistance = "metric.distance"
    case metricDistanceSubtitle = "metric.distance.subtitle"
    case metricElevation = "metric.elevation"
    case metricElevationSubtitle = "metric.elevation.subtitle"
    case metricExercise = "metric.exercise"
    case metricExerciseSubtitle = "metric.exercise.subtitle"
    case metricActivities = "metric.activities"
    case metricActivitiesSubtitle = "metric.activities.subtitle"

    // Data scopes
    case scopeAll = "scope.all"
    case scopeAllCaption = "scope.all.caption"
    case scopeActivities = "scope.activities"
    case scopeActivitiesCaption = "scope.activities.caption"

    // Dashboard
    case dashboardTotal = "dashboard.total"
    case dashboardAverage = "dashboard.average"
    case dashboardAveragePer = "dashboard.averagePer"
    case dashboardBest = "dashboard.best"
    case dashboardActivities = "dashboard.activities"

    // Charts
    case chartSection = "chart.section"
    case chartAveragePer = "chart.averagePer"
    case chartEmptyTitle = "chart.empty.title"
    case chartEmptyMessage = "chart.empty.message"
    case chartHint = "chart.hint"
    case chartHintPanned = "chart.hint.panned"
    case chartZoomIn = "chart.zoom.in"
    case chartZoomOut = "chart.zoom.out"
    case chartZoomReset = "chart.zoom.reset"
    case chartA11y = "chart.a11y"

    // Progress chart
    case progressSection = "progress.section"
    case progressCaption = "progress.caption"
    case progressThisPeriod = "progress.thisPeriod"
    case progressPreviousPeriod = "progress.previousPeriod"
    case progressLastYear = "progress.lastYear"
    case progressEmptyTitle = "progress.empty.title"
    case progressEmptyMessage = "progress.empty.message"
    case progressChartA11y = "progress.chart.a11y"

    // Recent activities
    case recentSection = "recent.section"
    case recentInPeriod = "recent.inPeriod"
    case recentEmpty = "recent.empty"

    // Comparison
    case comparisonPrevious = "comparison.previous"
    case comparisonLastYear = "comparison.lastYear"
    case comparisonCaptionPrevious = "comparison.caption.previous"
    case comparisonCaptionLastYear = "comparison.caption.lastYear"
    case comparisonUp = "comparison.up"
    case comparisonDown = "comparison.down"
    case comparisonFlat = "comparison.flat"
    case comparisonNone = "comparison.none"
    case comparisonBaselinePrevious = "comparison.baseline.previous"
    case comparisonBaselineLastYear = "comparison.baseline.lastYear"

    // Bucket nouns ("average per day")
    case bucketHour = "bucket.hour"
    case bucketDay = "bucket.day"
    case bucketWeek = "bucket.week"
    case bucketMonth = "bucket.month"

    // States
    case errorTitle = "error.title"
    case healthConnectTitle = "health.connect.title"
    case healthConnectBody = "health.connect.body"
    case healthUnavailableTitle = "health.unavailable.title"
    case healthUnavailableBody = "health.unavailable.body"

    // Activity log
    case logTitle = "log.title"
    case logEmptyTitle = "log.empty.title"
    case logEmptyBody = "log.empty.body"
    case logErrorTitle = "log.error.title"

    // Workout detail
    case detailSection = "detail.section"
    case detailDuration = "detail.duration"
    case detailDistance = "detail.distance"
    case detailAveragePace = "detail.averagePace"
    case detailElevation = "detail.elevation"
    case detailSteps = "detail.steps"
    case detailEnergy = "detail.energy"
    case detailAverageHeartRate = "detail.averageHeartRate"
    case detailMaxHeartRate = "detail.maxHeartRate"
    case detailSplits = "detail.splits"
    case detailMapAccessibility = "detail.map.accessibility"
    case detailRouteRecorded = "detail.route.recorded"
    case detailRouteDemo = "detail.route.demo"
    case detailRouteNoneTitle = "detail.route.none.title"
    case detailRouteNoneBody = "detail.route.none.body"
    case detailRouteNoneZero = "detail.route.none.zero"
    case detailRouteNoneUnlinked = "detail.route.none.unlinked"
    case detailRouteGrant = "detail.route.grant"
    case detailRouteDetails = "detail.route.details"
    case detailRouteSource = "detail.route.source"
    case detailRoutePoints = "detail.route.points"
    case detailRouteTraceTime = "detail.route.traceTime"
    case detailRouteWorkout = "detail.route.workout"
    case detailRouteRoutesInWindow = "detail.route.routesInWindow"

    // Activity kinds
    case kindRun = "kind.run"
    case kindWalk = "kind.walk"
    case kindRide = "kind.ride"
    case kindHike = "kind.hike"
    case kindSwim = "kind.swim"
    case kindStrength = "kind.strength"
    case kindYoga = "kind.yoga"
    case kindWorkout = "kind.workout"

    // Naming
    case namingMorning = "naming.time.morning"
    case namingAfternoon = "naming.time.afternoon"
    case namingEvening = "naming.time.evening"
    case namingNight = "naming.time.night"
    case namingTitle = "naming.title"
    case namingTitleNoPlace = "naming.title.noPlace"

    // Settings
    case settingsUnits = "settings.units"
    case settingsDistance = "settings.distance"
    case settingsElevation = "settings.elevation"
    case settingsUnitsFooter = "settings.units.footer"
    case settingsStatistics = "settings.statistics"
    case settingsDefaultPeriod = "settings.defaultPeriod"
    case settingsCompareWith = "settings.compareWith"
    case settingsShowByDefault = "settings.showByDefault"
    case settingsStatisticsFooter = "settings.statistics.footer"
    case settingsHealth = "settings.health"
    case settingsHealthStatus = "settings.health.status"
    case settingsHealthAvailable = "settings.health.available"
    case settingsHealthUnavailable = "settings.health.unavailable"
    case settingsHealthRequest = "settings.health.request"
    case settingsHealthOpen = "settings.health.open"
    case settingsHealthFooter = "settings.health.footer"
    case settingsHealthRequested = "settings.health.requested"
    case settingsDataSource = "settings.dataSource"
    case settingsDemo = "settings.demo"
    case settingsDemoFooter = "settings.demo.footer"
    case settingsCache = "settings.cache"
    case settingsCacheDays = "settings.cache.days"
    case settingsLastSync = "settings.lastSync"
    case settingsNever = "settings.never"
    case settingsCacheClear = "settings.cache.clear"
    case settingsCacheCleared = "settings.cache.cleared"
    case settingsAbout = "settings.about"
    case settingsVersion = "settings.version"
    case settingsMinimumIOS = "settings.minimumIOS"
    case settingsPrivacy = "settings.privacy"
    case settingsSupport = "settings.support"
    case settingsAboutFooter = "settings.about.footer"
    case settingsLanguage = "settings.language"
    case settingsLanguageSystem = "settings.language.system"
    case settingsLanguageFooter = "settings.language.footer"
    case settingsLanguageRestart = "settings.language.restart"

    // Sharing
    case shareButton = "share.button"
    case sharePreviewHint = "share.preview.hint"
    case shareCardTagline = "share.card.tagline"
    case shareErrorTitle = "share.error.title"
    case shareErrorBody = "share.error.body"

    // Units
    case unitDistanceKilometers = "unit.distance.km"
    case unitDistanceMiles = "unit.distance.mi"
    case unitElevationMeters = "unit.elevation.m"
    case unitElevationFeet = "unit.elevation.ft"
    case unitSteps = "unit.steps"
    case unitActivities = "unit.activities"
    case unitBpm = "unit.bpm"
    case unitKcal = "unit.kcal"

    // Value formats
    case valueSteps = "value.steps"
    case valueWithUnit = "value.withUnit"
    case valueA11y = "value.a11y"
    case durationHoursMinutes = "duration.hoursMinutes"
    case durationHours = "duration.hours"
    case durationMinutes = "duration.minutes"
    case paceValue = "pace.value"

    // Activity nouns used in workout names
    case nameRun = "name.run"
    case nameWalk = "name.walk"
    case nameRide = "name.ride"
    case nameHike = "name.hike"
    case nameSwim = "name.swim"
    case nameStrength = "name.strength"
    case nameYoga = "name.yoga"
    case nameWorkout = "name.workout"

    // Counted nouns
    case countActivityOne = "count.activity.one"
    case countActivityFew = "count.activity.few"
    case countActivityOther = "count.activity.other"
    case countDayOne = "count.day.one"
    case countDayFew = "count.day.few"
    case countDayOther = "count.day.other"
}

/// Loads a language's strings once and falls back to English, then to the key.
///
/// Reads are lock-guarded because the table is consulted from the domain layer
/// (metric titles, naming) as well as from views.
final class L10n: @unchecked Sendable {
    static let shared = L10n()

    /// A language for the current task only. Tests use it to render a language
    /// without changing what the app shows.
    @TaskLocal static var languageOverride: AppLanguage?

    private let lock = NSLock()
    private var tables: [AppLanguage: [String: String]] = [:]
    private var configured: AppLanguage = .english

    private init() {}

    /// The language in use: the task override, otherwise the configured one.
    var language: AppLanguage { Self.languageOverride ?? configured }

    /// Locale of the active language, for dates and numbers.
    var locale: Locale { language.locale }

    /// Configures the table for `language`. Safe to call more than once.
    func configure(language: AppLanguage) {
        let resolved = language == .system ? .english : language
        lock.lock()
        configured = resolved
        lock.unlock()
        _ = table(resolved)
    }

    func string(_ key: L10nKey) -> String {
        let language = self.language
        if let value = table(language)[key.rawValue] { return value }
        if let value = table(.english)[key.rawValue] { return value }
        return key.rawValue
    }

    /// Catalog for `language`, decoded once.
    private func table(_ language: AppLanguage) -> [String: String] {
        lock.lock()
        if let cached = tables[language] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let loaded = Self.load(language)
        lock.lock()
        tables[language] = loaded
        lock.unlock()
        return loaded
    }

    func string(_ key: L10nKey, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }

    /// Counted noun, e.g. "4 activities" / "5 aktivit".
    func counted(_ one: L10nKey, _ few: L10nKey, _ other: L10nKey, count: Int) -> String {
        let key: L10nKey
        switch language.pluralRule {
        case .otherOnly:
            key = other
        case .oneOther:
            key = count == 1 ? one : other
        case .oneFewOther:
            if count == 1 { key = one } else if (2...4).contains(count) { key = few } else { key = other }
        }
        return String(format: string(key), count)
    }

    private static func load(_ language: AppLanguage) -> [String: String] {
        guard let code = language.code else { return [:] }
        for bundle in bundles {
            if let url = bundle.url(forResource: code, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let table = try? JSONDecoder().decode([String: String].self, from: data) {
                return table
            }
        }
        return [:]
    }

    /// The app bundle first, then the bundle that contains this type, so the
    /// catalogs are also found from the test bundle.
    private static var bundles: [Bundle] {
        [Bundle.main, Bundle(for: L10n.self)]
    }
}

extension L10n {
    static func t(_ key: L10nKey) -> String { shared.string(key) }
    static func t(_ key: L10nKey, _ arguments: CVarArg...) -> String {
        String(format: shared.string(key), arguments: arguments)
    }
    static func count(_ one: L10nKey, _ few: L10nKey, _ other: L10nKey, _ value: Int) -> String {
        shared.counted(one, few, other, count: value)
    }
}

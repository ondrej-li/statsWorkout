import Foundation
import Testing
@testable import StatsWorkout

@Suite("Localization")
struct LocalizationTests {
    /// Every key must exist in every catalog, otherwise a screen falls back to
    /// English mid-sentence.
    @Test("Every language defines every key")
    func completeCatalogs() throws {
        for language in AppLanguage.allCases where language != .system {
            let table = try #require(Catalog.json(for: language), "missing catalog for \(language.rawValue)")
            let missing = Set(L10nKey.allCases.map(\.rawValue)).subtracting(table.keys)
            #expect(missing.isEmpty, "\(language.rawValue) is missing \(missing.sorted())")
            #expect(table.keys.count == L10nKey.allCases.count)
        }
    }

    @Test("No translation is left empty")
    func noEmptyValues() throws {
        for language in AppLanguage.allCases where language != .system {
            let table = try #require(Catalog.json(for: language))
            let empty = table.filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }
            #expect(empty.isEmpty, "\(language.rawValue) has empty values: \(empty.keys.sorted())")
        }
    }

    /// A `%@`-style placeholder that went missing in one language would print a
    /// sentence with a hole in it.
    @Test("Placeholders survive translation")
    func placeholdersMatch() throws {
        let english = try #require(Catalog.json(for: .english))
        for language in AppLanguage.allCases where language != .system && language != .english {
            let table = try #require(Catalog.json(for: language))
            for (key, englishValue) in english {
                let expected = Catalog.placeholders(in: englishValue)
                let actual = Catalog.placeholders(in: table[key] ?? "")
                #expect(expected == actual, "\(language.rawValue) \(key): \(actual) vs \(expected)")
            }
        }
    }

    @Test("System language follows the device and falls back to English")
    func resolve() {
        #expect(AppLanguage.resolve(selection: .system, preferredLanguages: ["cs-CZ", "en-US"]) == .czech)
        #expect(AppLanguage.resolve(selection: .system, preferredLanguages: ["de-AT"]) == .german)
        #expect(AppLanguage.resolve(selection: .system, preferredLanguages: ["zh-Hans-CN"]) == .chineseSimplified)
        #expect(AppLanguage.resolve(selection: .system, preferredLanguages: ["zh-Hant-TW"]) == .chineseSimplified)
        #expect(AppLanguage.resolve(selection: .system, preferredLanguages: ["hu-HU"]) == .english)
        #expect(AppLanguage.resolve(selection: .system, preferredLanguages: []) == .english)
        // An explicit choice always wins over the device.
        #expect(AppLanguage.resolve(selection: .korean, preferredLanguages: ["cs-CZ"]) == .korean)
    }

    @Test("Catalogs load and format in the chosen language")
    func formatting() {
        L10n.$languageOverride.withValue(.czech) {
            #expect(L10n.t(.metricSteps) == "Kroky")
            #expect(L10n.shared.locale.identifier == "cs")
        }

        L10n.$languageOverride.withValue(.japanese) {
            let formatter = MetricFormatter(units: .metric, locale: L10n.shared.locale)
            #expect(formatter.string(3_600, for: .exerciseDuration) == "1時間")
            #expect(formatter.string(12_345, for: .steps) == "12,345歩")
        }

        L10n.$languageOverride.withValue(.german) {
            let formatter = MetricFormatter(units: .metric, locale: L10n.shared.locale)
            #expect(formatter.string(12_345, for: .steps) == "12.345 Schritte")
        }

        // Outside the override the configured language is used again.
        #expect(L10n.shared.language == .english)
    }

    @Test("Plural forms follow each language's rules")
    func plurals() {
        L10n.$languageOverride.withValue(.english) {
            #expect(L10n.count(.countActivityOne, .countActivityFew, .countActivityOther, 1) == "1 activity")
            #expect(L10n.count(.countActivityOne, .countActivityFew, .countActivityOther, 3) == "3 activities")
        }

        // Czech distinguishes 2-4 from 5 and above.
        L10n.$languageOverride.withValue(.czech) {
            #expect(L10n.count(.countActivityOne, .countActivityFew, .countActivityOther, 1) == "1 aktivita")
            #expect(L10n.count(.countActivityOne, .countActivityFew, .countActivityOther, 3) == "3 aktivity")
            #expect(L10n.count(.countActivityOne, .countActivityFew, .countActivityOther, 8) == "8 aktivit")
        }

        // Japanese has a single form.
        L10n.$languageOverride.withValue(.japanese) {
            #expect(L10n.count(.countDayOne, .countDayFew, .countDayOther, 1) == "1日")
            #expect(L10n.count(.countDayOne, .countDayFew, .countDayOther, 9) == "9日")
        }
    }

    @Test("The language choice survives a relaunch")
    @MainActor
    func languageSettingPersists() throws {
        let name = "l10n-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.language == .system)

        settings.language = .japanese
        #expect(AppSettings.storedLanguage(in: defaults) == .japanese)

        // A fresh settings object - what the next launch does - reads it back.
        #expect(AppSettings(defaults: defaults).language == .japanese)
    }

    @Test("Workout names follow the language's word order")
    func workoutNames() {
        let calendar = TestSupport.calendar()
        let naming = WorkoutNaming(calendar: calendar)
        let walk = ActivitySample(
            kind: .walking,
            start: TestSupport.date(calendar, 2026, 11, 3, 7),
            end: TestSupport.date(calendar, 2026, 11, 3, 8)
        )

        L10n.$languageOverride.withValue(.english) {
            #expect(naming.title(for: walk, place: "Brtnice") == "Your morning walk around Brtnice")
        }
        L10n.$languageOverride.withValue(.czech) {
            #expect(naming.title(for: walk, place: "Brtnice") == "ranní procházka – Brtnice")
        }
        L10n.$languageOverride.withValue(.japanese) {
            #expect(naming.title(for: walk, place: "Brtnice") == "Brtnice周辺の朝のウォーキング")
        }
    }
}

/// Reads the shipped catalogs straight from the app bundle.
enum Catalog {
    static func json(for language: AppLanguage) -> [String: String]? {
        guard let code = language.code else { return nil }
        for bundle in [Bundle.main, Bundle(for: L10n.self)] {
            if let url = bundle.url(forResource: code, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let table = try? JSONDecoder().decode([String: String].self, from: data) {
                return table
            }
        }
        return nil
    }

    /// Placeholders keyed by position and kind, so `%2$02d` and `%2$d` match.
    static func placeholders(in value: String) -> [String] {
        let pattern = /%(?:(\d+)\$)?[-+ 0#]*\d*(?:\.\d+)?([@df])/
        return value.matches(of: pattern).map { match in
            (match.output.1.map(String.init) ?? "") + String(match.output.2)
        }.sorted()
    }
}

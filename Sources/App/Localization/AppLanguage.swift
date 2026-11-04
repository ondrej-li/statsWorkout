import Foundation

/// Languages the app ships with. `system` follows the device, falling back to
/// English when the device language is not one of these.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case czech
    case german
    case spanish
    case french
    case italian
    case portuguese
    case japanese
    case korean
    case chineseSimplified

    var id: String { rawValue }

    /// Resource name and `Locale` identifier; `nil` for `system`.
    var code: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .czech: return "cs"
        case .german: return "de"
        case .spanish: return "es"
        case .french: return "fr"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .chineseSimplified: return "zh-Hans"
        }
    }

    /// Name shown in the picker, written in the language itself.
    var displayName: String {
        switch self {
        case .system: return ""
        case .english: return "English"
        case .czech: return "Čeština"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .chineseSimplified: return "简体中文"
        }
    }

    var locale: Locale {
        Locale(identifier: code ?? "en")
    }

    /// Plural rules, as far as this app needs them.
    enum PluralRule: Sendable {
        case oneOther
        case oneFewOther
        case otherOnly
    }

    var pluralRule: PluralRule {
        switch self {
        case .czech: return .oneFewOther
        case .japanese, .korean, .chineseSimplified: return .otherOnly
        default: return .oneOther
        }
    }

    /// The language to load: an explicit choice, otherwise the best match for
    /// the device, otherwise English.
    static func resolve(selection: AppLanguage, preferredLanguages: [String]) -> AppLanguage {
        guard selection == .system else { return selection }
        for preferred in preferredLanguages {
            let tag = preferred.lowercased()
            if tag.hasPrefix("zh") { return .chineseSimplified }
            if let match = allCases.first(where: { $0.code.map(tag.hasPrefix) ?? false }) {
                return match
            }
        }
        return .english
    }
}

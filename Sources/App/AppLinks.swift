import Foundation

/// Public pages required by App Store review (privacy policy and support).
enum AppLinks {
    static let site = URL(string: "https://stats-workout.ondralinek.cz")!

    static var privacyPolicy: URL { page("privacy.html") }
    static var support: URL { page("support.html") }

    private static func page(_ name: String) -> URL {
        let prefersCzech = Locale.current.language.languageCode?.identifier == "cs"
        return site.appendingPathComponent(prefersCzech ? "cs/\(name)" : name)
    }
}

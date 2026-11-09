import SwiftUI

@main
struct StatsWorkoutApp: App {
    @State private var environment: AppEnvironment

    init() {
        // The catalog has to be loaded before the first string is built, and the
        // environment must see the same locale, so both happen here in order.
        let selection = AppSettings.storedLanguage()
        L10n.shared.configure(
            language: AppLanguage.resolve(
                selection: selection,
                preferredLanguages: Locale.preferredLanguages
            )
        )
        let environment = AppEnvironment.live()
        // The widget reads the shared container, so its copy of the language and
        // units is refreshed at every launch as well as on every change.
        environment.settings.mirrorToWidget()
        _environment = State(initialValue: environment)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var isRequestingAccess = false
    @State private var authorizationMessage: String?
    @State private var cacheInfo: HealthSyncCoordinator.CacheInfo?

    var body: some View {
        @Bindable var settings = environment.settings

        NavigationStack {
            Form {
                Section {
                    Picker(L10n.t(.settingsDistance), selection: $settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    Picker(L10n.t(.settingsElevation), selection: $settings.elevationUnit) {
                        ForEach(ElevationUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                } header: {
                    Text(L10n.t(.settingsUnits))
                } footer: {
                    Text(L10n.t(.settingsUnitsFooter, settings.distanceUnit.symbol, settings.elevationUnit.symbol))
                }

                Section {
                    Picker(L10n.t(.settingsLanguage), selection: $settings.language) {
                        Text(L10n.t(.settingsLanguageSystem, systemLanguage.displayName))
                            .tag(AppLanguage.system)
                        ForEach(AppLanguage.allCases.filter { $0 != .system }) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t(.settingsLanguageFooter))
                        if needsRestart {
                            Text(L10n.t(.settingsLanguageRestart))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    Picker(L10n.t(.settingsDefaultPeriod), selection: $settings.preferredPeriod) {
                        ForEach(PeriodKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    Picker(L10n.t(.settingsCompareWith), selection: $settings.comparisonMode) {
                        ForEach(ComparisonMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Picker(L10n.t(.settingsShowByDefault), selection: $settings.dataScope) {
                        ForEach(DataScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                } header: {
                    Text(L10n.t(.settingsStatistics))
                } footer: {
                    Text(L10n.t(.settingsStatisticsFooter))
                }

                Section {
                    LabeledContent(L10n.t(.settingsHealthStatus)) {
                        Text(environment.healthKit.isAvailable ? L10n.t(.settingsHealthAvailable) : L10n.t(.settingsHealthUnavailable))
                            .foregroundStyle(environment.healthKit.isAvailable ? .green : .secondary)
                    }

                    Button {
                        Task { await requestAccess() }
                    } label: {
                        HStack {
                            Text(isRequestingAccess ? L10n.t(.actionRequesting) : L10n.t(.settingsHealthRequest))
                            Spacer()
                            if isRequestingAccess { ProgressView() }
                        }
                    }
                    .disabled(isRequestingAccess || !environment.healthKit.isAvailable)

                    Button(L10n.t(.settingsHealthOpen)) {
                        if let url = URL(string: "x-apple-health://") {
                            openURL(url)
                        }
                    }
                    .disabled(!environment.healthKit.isAvailable)

                    if let authorizationMessage {
                        Text(authorizationMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(L10n.t(.settingsHealth))
                } footer: {
                    Text(L10n.t(.settingsHealthFooter))
                }

                Section {
                    Toggle(L10n.t(.settingsDemo), isOn: $settings.useMockData)
                        .onChange(of: settings.useMockData) { _, usesMock in
                            environment.invalidateCache()
                            if !usesMock {
                                environment.startBackgroundDelivery()
                            }
                            Task { await refreshCacheInfo() }
                        }

                    LabeledContent(L10n.t(.settingsCache)) {
                        Text(cacheInfo.map { L10n.t(.settingsCacheDays, $0.dayCount) } ?? "—")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    LabeledContent(L10n.t(.settingsLastSync)) {
                        Text(cacheInfo?.lastSyncedAt.map {
                            $0.formatted(.relative(presentation: .named).locale(environment.locale))
                        } ?? L10n.t(.settingsNever))
                            .foregroundStyle(.secondary)
                    }
                    Button(L10n.t(.settingsCacheClear)) {
                        environment.invalidateCache()
                        Task {
                            await refreshCacheInfo()
                            authorizationMessage = L10n.t(.settingsCacheCleared)
                        }
                    }
                    .disabled((cacheInfo?.dayCount ?? 0) == 0)
                } header: {
                    Text(L10n.t(.settingsDataSource))
                } footer: {
                    Text(L10n.t(.settingsDemoFooter))
                }

                Section {
                    LabeledContent(L10n.t(.settingsVersion), value: Bundle.main.appVersion)
                    LabeledContent(L10n.t(.settingsMinimumIOS), value: "26.0")
                    Link(L10n.t(.settingsPrivacy), destination: AppLinks.privacyPolicy)
                    Link(L10n.t(.settingsSupport), destination: AppLinks.support)
                } header: {
                    Text(L10n.t(.settingsAbout))
                } footer: {
                    Text(L10n.t(.settingsAboutFooter))
                }
            }
            .navigationTitle(L10n.t(.tabSettings))
            .task { await refreshCacheInfo() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refreshCacheInfo() }
            }
        }
    }

    /// The language the device would pick, shown next to "System".
    private var systemLanguage: AppLanguage {
        AppLanguage.resolve(selection: .system, preferredLanguages: Locale.preferredLanguages)
    }

    /// The chosen language is read at launch, so a change only takes effect on
    /// the next start.
    private var needsRestart: Bool {
        AppLanguage.resolve(
            selection: environment.settings.language,
            preferredLanguages: Locale.preferredLanguages
        ) != L10n.shared.language
    }

    private func refreshCacheInfo() async {
        cacheInfo = await environment.sync.cacheInfo(sourceKey: environment.dataSourceKey)
    }

    private func requestAccess() async {
        isRequestingAccess = true
        defer { isRequestingAccess = false }
        do {
            try await environment.healthKit.requestAuthorization()
            environment.startBackgroundDelivery()
            authorizationMessage = L10n.t(.settingsHealthRequested)
        } catch {
            authorizationMessage = error.localizedDescription
        }
    }
}

private extension Bundle {
    var appVersion: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .environment(AppEnvironment.preview())
}

#endif

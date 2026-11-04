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
                    Picker("Distance", selection: $settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    Picker("Elevation", selection: $settings.elevationUnit) {
                        ForEach(ElevationUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Distance is shown in \(settings.distanceUnit.symbol) and elevation in \(settings.elevationUnit.symbol).")
                }

                Section {
                    Picker("Default period", selection: $settings.preferredPeriod) {
                        ForEach(PeriodKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    Picker("Compare with", selection: $settings.comparisonMode) {
                        ForEach(ComparisonMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Picker("Show by default", selection: $settings.dataScope) {
                        ForEach(DataScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                } header: {
                    Text("Statistics")
                } footer: {
                    Text("The default period, the comparison baseline and whether the dashboard starts with continuous data or workout-only data. Both can be changed on the dashboard too.")
                }

                Section {
                    LabeledContent("Status") {
                        Text(environment.healthKit.isAvailable ? "Available" : "Unavailable")
                            .foregroundStyle(environment.healthKit.isAvailable ? .green : .secondary)
                    }

                    Button {
                        Task { await requestAccess() }
                    } label: {
                        HStack {
                            Text(isRequestingAccess ? "Requesting…" : "Request read access")
                            Spacer()
                            if isRequestingAccess { ProgressView() }
                        }
                    }
                    .disabled(isRequestingAccess || !environment.healthKit.isAvailable)

                    Button("Open Health app") {
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
                    Text("Apple Health")
                } footer: {
                    Text("HealthKit never reports whether read access was granted. If charts stay empty, check access in the Health app under Sharing → Apps.")
                }

                Section {
                    Toggle("Use demo data", isOn: $settings.useMockData)
                        .onChange(of: settings.useMockData) { _, usesMock in
                            environment.invalidateCache()
                            if !usesMock {
                                environment.startBackgroundDelivery()
                            }
                            Task { await refreshCacheInfo() }
                        }

                    LabeledContent("Offline cache") {
                        Text(cacheInfo.map { "\($0.dayCount) days" } ?? "—")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    LabeledContent("Last sync") {
                        Text(cacheInfo?.lastSyncedAt.map { $0.formatted(.relative(presentation: .named)) } ?? "Never")
                            .foregroundStyle(.secondary)
                    }
                    Button("Clear cached samples") {
                        environment.invalidateCache()
                        Task {
                            await refreshCacheInfo()
                            authorizationMessage = "Cache cleared. It will be rebuilt on the next load."
                        }
                    }
                    .disabled((cacheInfo?.dayCount ?? 0) == 0)
                } header: {
                    Text("Data source")
                } footer: {
                    Text("Demo data is generated on device and is handy for previewing the dashboard in the simulator. Daily totals are cached on this device and refreshed in the background, so a month or year view does not re-read every sample each time.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.appVersion)
                    LabeledContent("Minimum iOS", value: "26.0")
                    Link("Privacy policy", destination: AppLinks.privacyPolicy)
                    Link("Support", destination: AppLinks.support)
                } header: {
                    Text("About")
                } footer: {
                    Text("StatsWorkout is made by Ondřej Linek. Questions: ondrej.linek@gmail.com")
                }
            }
            .navigationTitle("Settings")
            .task { await refreshCacheInfo() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refreshCacheInfo() }
            }
        }
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
            authorizationMessage = "Request completed. Turn off demo data to see Apple Health values."
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

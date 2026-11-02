import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openURL) private var openURL

    @State private var isRequestingAccess = false
    @State private var authorizationMessage: String?

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
                } header: {
                    Text("Statistics")
                } footer: {
                    Text("Used when the app opens and when charts show a comparison.")
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
                } header: {
                    Text("Data source")
                } footer: {
                    Text("Demo data is generated on device and is handy for previewing the dashboard in the simulator. Turn it off to use Apple Health.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.appVersion)
                    LabeledContent("Minimum iOS", value: "26.0")
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func requestAccess() async {
        isRequestingAccess = true
        defer { isRequestingAccess = false }
        do {
            try await environment.healthKit.requestAuthorization()
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

#Preview {
    SettingsView()
        .environment(AppEnvironment.preview())
}

import Foundation

protocol HealthCacheStoring: Sendable {
    func load() async -> HealthSampleCache?
    func save(_ cache: HealthSampleCache) async
    func clear() async
}

/// File-backed cache in Application Support: small, atomic and easy to inspect
/// with a text editor while debugging.
struct FileHealthCacheStore: HealthCacheStoring {
    private let url: URL

    init(url: URL = FileHealthCacheStore.defaultURL) {
        self.url = url
    }

    static var defaultURL: URL {
        let directory = URL.applicationSupportDirectory.appending(path: "StatsWorkout", directoryHint: .isDirectory)
        return directory.appending(path: "health-cache.json")
    }

    func load() async -> HealthSampleCache? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cache = try? decoder.decode(HealthSampleCache.self, from: data),
              cache.version == HealthSampleCache.currentVersion else { return nil }
        return cache
    }

    func save(_ cache: HealthSampleCache) async {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: url, options: .atomic)
        } catch {
            // A failed cache write must never break a refresh; the next load
            // simply re-reads HealthKit.
        }
    }

    func clear() async {
        try? FileManager.default.removeItem(at: url)
    }
}

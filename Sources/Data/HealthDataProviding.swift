import Foundation

/// Whether the app still has to show the system Health permission sheet.
enum HealthAuthorizationStatus: Sendable, Equatable {
    case shouldRequest
    case unnecessary
    case unknown
}

enum HealthDataError: LocalizedError, Sendable {
    case unavailable
    case authorizationNotDetermined
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health is not available on this device."
        case .authorizationNotDetermined:
            return "Apple Health access has not been granted yet."
        case .queryFailed(let message):
            return "Could not read Apple Health data: \(message)"
        }
    }

    var isAuthorizationNotDetermined: Bool {
        if case .authorizationNotDetermined = self { return true }
        return false
    }
}

/// Resolution requested for step samples. Hourly samples back the day and
/// 24-hour views; daily samples are enough for everything else.
enum StepGranularity: Sendable, Hashable {
    case hour
    case day
}

/// Abstraction over Apple Health so the UI can run on mock data and tests never touch HealthKit.
protocol HealthDataProviding: Sendable {
    var isAvailable: Bool { get }
    func authorizationRequestStatus() async throws -> HealthAuthorizationStatus
    func requestAuthorization() async throws
    func activities(in interval: DateInterval) async throws -> [ActivitySample]
    func stepSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [StepSample]
}

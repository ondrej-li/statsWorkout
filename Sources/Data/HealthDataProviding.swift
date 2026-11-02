import Foundation

enum HealthDataError: LocalizedError, Sendable {
    case unavailable
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health is not available on this device."
        case .queryFailed(let message):
            return "Could not read Apple Health data: \(message)"
        }
    }
}

/// Abstraction over Apple Health so the UI can run on mock data and tests never touch HealthKit.
protocol HealthDataProviding: Sendable {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    func activities(in interval: DateInterval) async throws -> [ActivitySample]
    func dailySteps(in interval: DateInterval) async throws -> [StepSample]
}

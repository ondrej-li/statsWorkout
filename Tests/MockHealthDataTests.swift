import Foundation
import Testing
@testable import StatsWorkout

@Suite("Mock health data")
struct MockHealthDataTests {
    private let calendar = TestSupport.calendar()

    private var window: DateInterval {
        DateInterval(
            start: TestSupport.date(calendar, 2026, 10, 1),
            end: TestSupport.date(calendar, 2026, 12, 1)
        )
    }

    @Test("Step samples never run past the current time")
    func stepsStopAtNow() {
        let now = TestSupport.date(calendar, 2026, 11, 2, 10, 0)
        let samples = MockHealthData.dailySteps(in: window, calendar: calendar, seed: 42, now: now)

        #expect(!samples.isEmpty)
        #expect(samples.first?.day == TestSupport.date(calendar, 2026, 10, 1))
        #expect(samples.allSatisfy { $0.day < now })
        #expect(samples.allSatisfy { $0.count > 0 })
    }

    @Test("Activities fall inside the queried interval and before now")
    func activitiesStayInWindow() {
        let now = TestSupport.date(calendar, 2026, 11, 2, 10, 0)
        let activities = MockHealthData.activities(in: window, calendar: calendar, seed: 42, now: now)

        #expect(!activities.isEmpty)
        #expect(activities.allSatisfy { $0.start >= window.start && $0.start < now })
        #expect(activities.allSatisfy { $0.end > $0.start })
    }

    @Test("Generation is deterministic for a fixed seed")
    func deterministic() {
        let now = TestSupport.date(calendar, 2026, 11, 2, 10, 0)
        let first = MockHealthData.dailySteps(in: window, calendar: calendar, seed: 7, now: now)
        let second = MockHealthData.dailySteps(in: window, calendar: calendar, seed: 7, now: now)

        #expect(first == second)
    }

    @Test("Mock source needs no system authorization")
    func mockAuthorization() async throws {
        let source = MockHealthDataSource(calendar: calendar)
        #expect(source.isAvailable)
        #expect(try await source.authorizationRequestStatus() == .unnecessary)
    }
}

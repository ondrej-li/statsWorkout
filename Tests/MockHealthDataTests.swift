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
        #expect(samples.first?.start == TestSupport.date(calendar, 2026, 10, 1))
        #expect(samples.allSatisfy { $0.start < now })
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

    @Test("Hourly samples are aligned, bounded and cover the elapsed hours")
    func hourlySamples() {
        let now = TestSupport.date(calendar, 2026, 11, 2, 10, 30)
        let samples = MockHealthData.hourlySteps(in: window, calendar: calendar, seed: 3, now: now)

        #expect(!samples.isEmpty)
        #expect(samples.allSatisfy { $0.start < now })
        #expect(samples.allSatisfy { $0.end.timeIntervalSince($0.start) == 3_600 })
        #expect(samples.last?.start == TestSupport.date(calendar, 2026, 11, 2, 10))
        #expect(samples.allSatisfy { $0.count >= 0 })
    }

    @Test("Continuous totals always contain the workout share")
    func continuousContainsWorkouts() {
        let now = TestSupport.date(calendar, 2026, 11, 2, 10, 0)
        let steps = MockHealthData.dailySteps(in: window, calendar: calendar, seed: 5, now: now)
        let distance = MockHealthData.distanceSamples(
            in: window, granularity: .day, calendar: calendar, seed: 5, now: now
        )
        let activities = MockHealthData.activities(in: window, calendar: calendar, seed: 5, now: now)
        let windows = activities.map { DateInterval(start: $0.start, end: $0.end) }
        let workoutSteps = MockHealthData.workoutQuantitySamples(
            in: window, kind: .steps, within: windows, granularity: .day,
            calendar: calendar, seed: 5, now: now
        )
        let workoutDistance = MockHealthData.workoutQuantitySamples(
            in: window, kind: .distance, within: windows, granularity: .day,
            calendar: calendar, seed: 5, now: now
        )

        #expect(!steps.isEmpty)
        #expect(!distance.isEmpty)
        #expect(!workoutSteps.isEmpty)
        #expect(steps.allSatisfy { $0.count > 0 })
        #expect(distance.allSatisfy { $0.value > 0 })

        // A workout's own figures are part of the continuous totals, never on top of them.
        #expect(workoutSteps.reduce(0) { $0 + $1.value } < steps.reduce(0) { $0 + $1.count })
        #expect(workoutDistance.reduce(0) { $0 + $1.value } < distance.reduce(0) { $0 + $1.value })
    }

    @Test("Continuous elevation is derived from flights climbed")
    func elevationSamples() {
        let now = TestSupport.date(calendar, 2026, 11, 2, 10, 0)
        let samples = MockHealthData.elevationSamples(
            in: window, granularity: .day, calendar: calendar, seed: 5, now: now
        )

        #expect(!samples.isEmpty)
        #expect(samples.allSatisfy { $0.start < now })
        #expect(samples.allSatisfy { $0.value > 0 })
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

import Foundation

/// Deterministic stand-in for HealthKit so the app is fully usable in the
/// simulator and in SwiftUI previews. Data is generated from a fixed seed, so
/// charts look identical on every launch.
struct MockHealthDataSource: HealthDataProviding {
    var calendar: Calendar
    var seed: UInt64

    init(calendar: Calendar = .current, seed: UInt64 = 0x5EED_1234) {
        self.calendar = calendar
        self.seed = seed
    }

    var isAvailable: Bool { true }

    func authorizationRequestStatus() async throws -> HealthAuthorizationStatus { .unnecessary }

    func requestAuthorization() async throws {}

    func activities(in interval: DateInterval) async throws -> [ActivitySample] {
        MockHealthData.activities(in: interval, calendar: calendar, seed: seed)
    }

    func dailySteps(in interval: DateInterval) async throws -> [StepSample] {
        MockHealthData.dailySteps(in: interval, calendar: calendar, seed: seed)
    }
}

enum MockHealthData {
    private static let referenceDate = Date(timeIntervalSinceReferenceDate: 0)

    static func activities(in interval: DateInterval, calendar: Calendar, seed: UInt64, now: Date = Date()) -> [ActivitySample] {
        guard interval.duration > 0 else { return [] }

        var result: [ActivitySample] = []
        var day = calendar.startOfDay(for: interval.start)
        let limit = min(interval.end, now)

        while day < limit {
            let index = UInt64(dayIndex(for: day, calendar: calendar))
            let roll = unitRandom(seed, index &* 7 &+ 1)
            let workoutsToday = roll < 0.42 ? 0 : (roll < 0.86 ? 1 : 2)

            for slot in 0..<workoutsToday {
                let localSeed = seed &+ index &* 131 &+ UInt64(slot) &* 17
                result.append(makeActivity(localSeed: localSeed, day: day, calendar: calendar, index: index, slot: slot))
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return result.filter { $0.start >= interval.start && $0.start < limit }
    }

    static func dailySteps(in interval: DateInterval, calendar: Calendar, seed: UInt64, now: Date = Date()) -> [StepSample] {
        guard interval.duration > 0 else { return [] }

        var result: [StepSample] = []
        var day = calendar.startOfDay(for: interval.start)
        let limit = min(interval.end, now)

        while day < limit {
            let index = UInt64(dayIndex(for: day, calendar: calendar))
            let noise = unitRandom(seed &+ 999, index)
            let weekday = calendar.component(.weekday, from: day)
            let weekend = (weekday == 1 || weekday == 7) ? 1.18 : 1.0
            let seasonal = 0.9 + 0.22 * sin(Double(index) / 61.0)
            let dayFraction: Double = calendar.isDate(day, inSameDayAs: now)
                ? max(0.05, now.timeIntervalSince(calendar.startOfDay(for: day)) / 86_400)
                : 1
            let steps = max(0, (5_200 + noise * 7_400) * weekend * seasonal * dayFraction)
            result.append(StepSample(day: day, count: (steps / 10).rounded() * 10))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return result.filter { $0.day < limit && $0.day.addingTimeInterval(86_400) > interval.start }
    }

    // MARK: - Generation

    private static func makeActivity(localSeed: UInt64, day: Date, calendar: Calendar, index: UInt64, slot: Int) -> ActivitySample {
        let kindRoll = unitRandom(localSeed, 1)
        let kind: ActivityKind
        switch kindRoll {
        case ..<0.34: kind = .running
        case ..<0.56: kind = .walking
        case ..<0.72: kind = .cycling
        case ..<0.82: kind = .hiking
        case ..<0.88: kind = .swimming
        case ..<0.95: kind = .strength
        default: kind = .yoga
        }

        let hour = 6 + Int(unitRandom(localSeed, 2) * 11)
        let minute = Int(unitRandom(localSeed, 3) * 60)
        let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        let durationMinutes = 20 + unitRandom(localSeed, 4) * 70
        let end = start.addingTimeInterval(durationMinutes * 60)

        let distanceMeters: Double? = {
            guard kind.isDistanceBased else { return nil }
            let speedKmh: Double
            switch kind {
            case .running: speedKmh = 9.5 + unitRandom(localSeed, 5) * 4.5
            case .walking: speedKmh = 4.2 + unitRandom(localSeed, 5) * 1.6
            case .cycling: speedKmh = 19 + unitRandom(localSeed, 5) * 12
            case .hiking: speedKmh = 3.4 + unitRandom(localSeed, 5) * 1.8
            case .swimming: speedKmh = 1.6 + unitRandom(localSeed, 5) * 0.9
            default: speedKmh = 0
            }
            return speedKmh * (durationMinutes / 60) * 1_000
        }()

        let elevationMeters: Double? = {
            switch kind {
            case .hiking: return 180 + unitRandom(localSeed, 6) * 620
            case .running: return 8 + unitRandom(localSeed, 6) * 90
            case .walking: return 4 + unitRandom(localSeed, 6) * 40
            case .cycling: return 30 + unitRandom(localSeed, 6) * 180
            default: return nil
            }
        }()

        let energy = distanceMeters.map { $0 / 1_000 * 62 } ?? (durationMinutes * 6.5)

        return ActivitySample(
            id: deterministicUUID(localSeed),
            kind: kind,
            start: start,
            end: end,
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationMeters,
            activeEnergyKilocalories: energy
        )
    }

    // MARK: - Deterministic randomness

    private static func dayIndex(for date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
    }

    private static func splitMix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Stable pseudo-random value in `0..<1`.
    private static func unitRandom(_ seed: UInt64, _ salt: UInt64) -> Double {
        let value = splitMix(seed &+ salt &* 0x9E37_79B9_7F4A_7C15)
        return Double(value >> 11) / Double(UInt64(1) << 53)
    }

    private static func deterministicUUID(_ seed: UInt64) -> UUID {
        let high = splitMix(seed)
        let low = splitMix(high)
        var bytes = uuid_t(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        withUnsafeMutableBytes(of: &bytes) { buffer in
            for index in 0..<8 {
                buffer[index] = UInt8(truncatingIfNeeded: high >> (8 * (7 - index)))
                buffer[8 + index] = UInt8(truncatingIfNeeded: low >> (8 * (7 - index)))
            }
        }
        return UUID(uuid: bytes)
    }
}

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

    func stepSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [StepSample] {
        MockHealthData.stepSamples(in: interval, granularity: granularity, calendar: calendar, seed: seed)
    }

    func distanceSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [QuantitySample] {
        MockHealthData.distanceSamples(in: interval, granularity: granularity, calendar: calendar, seed: seed)
    }

    func elevationSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [QuantitySample] {
        MockHealthData.elevationSamples(in: interval, granularity: granularity, calendar: calendar, seed: seed)
    }

    func workoutQuantitySamples(
        in interval: DateInterval,
        kind: ContinuousQuantity,
        within windows: [DateInterval],
        granularity: StepGranularity
    ) async throws -> [QuantitySample] {
        MockHealthData.workoutQuantitySamples(
            in: interval,
            kind: kind,
            within: windows,
            granularity: granularity,
            calendar: calendar,
            seed: seed
        )
    }
}

enum MockHealthData {
    private static let referenceDate = Date(timeIntervalSinceReferenceDate: 0)

    /// Relative likelihood of steps in each hour of the day.
    private static let hourlyWeights: [Double] = [
        0.30, 0.20, 0.15, 0.15, 0.30, 0.80,
        1.60, 2.60, 2.20, 1.60, 1.40, 1.50,
        1.70, 1.60, 1.50, 1.70, 2.20, 2.60,
        2.00, 1.40, 1.00, 0.80, 0.60, 0.40
    ]

    // MARK: - Activities

    static func activities(
        in interval: DateInterval,
        calendar: Calendar,
        seed: UInt64,
        now: Date = Date()
    ) -> [ActivitySample] {
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
                result.append(makeActivity(localSeed: localSeed, day: day, calendar: calendar))
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        // The demo always shows something recent: if today rolled no workout,
        // add one a few hours before now.
        let today = calendar.startOfDay(for: now)
        if !result.contains(where: { calendar.isDate($0.start, inSameDayAs: today) }) {
            let localSeed = seed &+ UInt64(dayIndex(for: today, calendar: calendar)) &* 5_003 &+ 77
            var activity = makeActivity(localSeed: localSeed, day: today, calendar: calendar)
            activity = clamped(activity, endingBefore: now, calendar: calendar)
            if activity.end > interval.start, activity.start < limit,
               activity.start >= calendar.startOfDay(for: interval.start) {
                result.append(activity)
            }
        }

        return result.filter { $0.start >= interval.start && $0.start < limit }
    }

    // MARK: - Steps and distance

    static func stepSamples(
        in interval: DateInterval,
        granularity: StepGranularity,
        calendar: Calendar,
        seed: UInt64,
        now: Date = Date()
    ) -> [StepSample] {
        switch granularity {
        case .day:
            return dailySteps(in: interval, calendar: calendar, seed: seed, now: now)
        case .hour:
            return hourlySteps(in: interval, calendar: calendar, seed: seed, now: now)
        }
    }

    static func dailySteps(
        in interval: DateInterval,
        calendar: Calendar,
        seed: UInt64,
        now: Date = Date()
    ) -> [StepSample] {
        guard interval.duration > 0 else { return [] }

        var buckets: [Date: (end: Date, value: Double)] = [:]
        for hour in hourlyBreakdown(in: interval, calendar: calendar, seed: seed, now: now) {
            let day = calendar.startOfDay(for: hour.start)
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? hour.end
            buckets[day] = (end, (buckets[day]?.value ?? 0) + hour.steps)
        }

        return buckets
            .sorted { $0.key < $1.key }
            .map { StepSample(start: $0.key, end: $0.value.end, count: roundedToFive($0.value.value)) }
            .filter { $0.count > 0 }
    }

    static func hourlySteps(
        in interval: DateInterval,
        calendar: Calendar,
        seed: UInt64,
        now: Date = Date()
    ) -> [StepSample] {
        hourlyBreakdown(in: interval, calendar: calendar, seed: seed, now: now)
            .map { StepSample(start: $0.start, end: $0.end, count: roundedToFive($0.steps)) }
            .filter { $0.count > 0 }
    }

    static func distanceSamples(
        in interval: DateInterval,
        granularity: StepGranularity,
        calendar: Calendar,
        seed: UInt64,
        now: Date = Date()
    ) -> [QuantitySample] {
        guard interval.duration > 0 else { return [] }

        var buckets: [Date: (end: Date, value: Double)] = [:]
        for hour in hourlyBreakdown(in: interval, calendar: calendar, seed: seed, now: now) {
            let start = granularity == .hour ? hour.start : calendar.startOfDay(for: hour.start)
            let end = granularity == .hour
                ? hour.end
                : calendar.date(byAdding: .day, value: 1, to: start) ?? hour.end
            buckets[start] = (end, (buckets[start]?.value ?? 0) + hour.distance)
        }

        return buckets
            .sorted { $0.key < $1.key }
            .map { QuantitySample(start: $0.key, end: $0.value.end, value: $0.value.value.rounded()) }
            .filter { $0.value > 0 }
    }

    /// Steps and distance recorded inside the workout windows, at the requested
    /// resolution. Mirrors HealthKit, where these are ordinary samples that fall
    /// between the workout's start and end.
    static func workoutQuantitySamples(
        in interval: DateInterval,
        kind: ContinuousQuantity,
        within windows: [DateInterval],
        granularity: StepGranularity,
        calendar: Calendar,
        seed: UInt64,
        now: Date = Date()
    ) -> [QuantitySample] {
        guard interval.duration > 0, !windows.isEmpty else { return [] }

        var totals: [Date: (end: Date, value: Double)] = [:]

        for hour in hourlyBreakdown(in: interval, calendar: calendar, seed: seed, now: now) {
            let overlap = windows.reduce(0.0) { partial, window in
                let start = max(hour.start, window.start)
                let end = min(hour.end, window.end)
                return partial + max(0, end.timeIntervalSince(start))
            }
            guard overlap > 0, hour.duration > 0 else { continue }

            let fraction = min(1, overlap / hour.duration)
            let value = (kind == .steps ? hour.steps : hour.distance) * fraction
            guard value > 0 else { continue }

            let bucketStart = granularity == .hour ? hour.start : calendar.startOfDay(for: hour.start)
            let bucketEnd = granularity == .hour
                ? hour.end
                : calendar.date(byAdding: .day, value: 1, to: bucketStart) ?? hour.end

            let existing = totals[bucketStart]
            totals[bucketStart] = (bucketEnd, (existing?.value ?? 0) + value)
        }

        return totals
            .map { QuantitySample(start: $0.key, end: $0.value.end, value: $0.value.value.rounded()) }
            .filter { $0.value > 0 }
            .sorted { $0.start < $1.start }
    }

    // MARK: - Continuous elevation

    static func elevationSamples(
        in interval: DateInterval,
        granularity: StepGranularity,
        calendar: Calendar,
        seed: UInt64,
        now: Date = Date()
    ) -> [QuantitySample] {
        guard interval.duration > 0 else { return [] }
        let limit = min(interval.end, now)

        var result: [QuantitySample] = []
        var cursor = calendar.startOfDay(for: interval.start)
        let weightSum = hourlyWeights.reduce(0, +)

        while cursor < limit {
            let dayIndexValue = UInt64(dayIndex(for: cursor, calendar: calendar))
            let flights = (unitRandom(seed &+ 777, dayIndexValue) * 14).rounded()
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: cursor) ?? limit

            if flights > 0 {
                switch granularity {
                case .day:
                    let end = min(dayEnd, limit)
                    if end > interval.start {
                        result.append(
                            QuantitySample(
                                start: max(cursor, interval.start),
                                end: end,
                                value: flights * WorkoutMapper.metersPerFlight
                            )
                        )
                    }
                case .hour:
                    for hour in 0..<24 {
                        guard let start = calendar.date(byAdding: .hour, value: hour, to: cursor),
                              start < limit else { continue }
                        let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? limit
                        let value = flights * WorkoutMapper.metersPerFlight * hourlyWeights[hour] / weightSum
                        guard value > 0 else { continue }
                        result.append(QuantitySample(start: start, end: end, value: value))
                    }
                }
            }

            cursor = dayEnd
        }

        return result
    }

    // MARK: - Hourly breakdown

    /// One hour of generated activity: ambient movement plus whatever a workout
    /// contributed, so continuous totals always contain the workout figures and
    /// never disagree with them.
    private struct Hour {
        let start: Date
        let end: Date
        var ambientSteps: Double
        var ambientDistance: Double
        var workoutSteps: Double
        var workoutDistance: Double

        var duration: TimeInterval { end.timeIntervalSince(start) }
        var steps: Double { ambientSteps + workoutSteps }
        var distance: Double { ambientDistance + workoutDistance }
    }

    private static func hourlyBreakdown(
        in interval: DateInterval,
        calendar: Calendar,
        seed: UInt64,
        now: Date
    ) -> [Hour] {
        guard interval.duration > 0 else { return [] }
        let limit = min(interval.end, now)
        let workouts = activities(in: interval, calendar: calendar, seed: seed, now: now)
        let weightSum = hourlyWeights.reduce(0, +)

        var hours: [Hour] = []
        var cursor = calendar.dateInterval(of: .hour, for: interval.start)?.start ?? interval.start

        while cursor < limit {
            let end = calendar.date(byAdding: .hour, value: 1, to: cursor) ?? limit
            let day = calendar.startOfDay(for: cursor)
            let hour = calendar.component(.hour, from: cursor)
            let elapsedFraction: Double = end <= now
                ? 1
                : max(0.02, now.timeIntervalSince(cursor) / max(end.timeIntervalSince(cursor), 1))

            let ambient = dailyTotal(for: day, calendar: calendar, seed: seed)
                * hourlyWeights[hour] / weightSum
                * elapsedFraction

            var entry = Hour(
                start: cursor,
                end: end,
                ambientSteps: ambient,
                ambientDistance: ambient * 0.78,
                workoutSteps: 0,
                workoutDistance: 0
            )

            for workout in workouts where workout.end > cursor && workout.start < end {
                let overlapStart = max(cursor, workout.start)
                let overlapEnd = min(end, workout.end)
                let share = workout.duration > 0
                    ? max(0, overlapEnd.timeIntervalSince(overlapStart)) / workout.duration
                    : 0
                entry.workoutSteps += (workout.stepCount ?? 0) * share
                entry.workoutDistance += (workout.distanceMeters ?? 0) * share
            }

            hours.append(entry)
            cursor = end
        }

        return hours
    }

    private static func dailyTotal(for day: Date, calendar: Calendar, seed: UInt64) -> Double {
        let index = UInt64(dayIndex(for: day, calendar: calendar))
        let noise = unitRandom(seed &+ 999, index)
        let weekday = calendar.component(.weekday, from: day)
        let weekend = (weekday == 1 || weekday == 7) ? 1.18 : 1.0
        let seasonal = 0.9 + 0.22 * sin(Double(index) / 61.0)
        return max(0, (4_400 + noise * 6_600) * weekend * seasonal)
    }

    private static func roundedToFive(_ value: Double) -> Double {
        (value / 5).rounded() * 5
    }

    // MARK: - Generation

    private static func clamped(_ activity: ActivitySample, endingBefore now: Date, calendar: Calendar) -> ActivitySample {
        guard activity.end > now else { return activity }
        let duration = min(activity.duration, 45 * 60)
        let end = now
        let start = max(calendar.startOfDay(for: now), end.addingTimeInterval(-duration))
        return ActivitySample(
            id: activity.id,
            kind: activity.kind,
            start: start,
            end: end,
            distanceMeters: activity.distanceMeters.map { $0 * (end.timeIntervalSince(start) / max(activity.duration, 1)) },
            elevationGainMeters: activity.elevationGainMeters,
            stepCount: activity.stepCount.map { $0 * (end.timeIntervalSince(start) / max(activity.duration, 1)) },
            activeEnergyKilocalories: activity.activeEnergyKilocalories
        )
    }

    private static func makeActivity(localSeed: UInt64, day: Date, calendar: Calendar) -> ActivitySample {
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
        let durationMinutes = 22 + unitRandom(localSeed, 4) * 58
        let end = start.addingTimeInterval(durationMinutes * 60)

        let distanceMeters: Double? = {
            guard kind.isDistanceBased else { return nil }
            let speedKmh: Double
            switch kind {
            case .running: speedKmh = 8.8 + unitRandom(localSeed, 5) * 3.4
            case .walking: speedKmh = 4.2 + unitRandom(localSeed, 5) * 1.6
            case .cycling: speedKmh = 18 + unitRandom(localSeed, 5) * 9
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

        let stepCount: Double? = {
            guard let distanceMeters else { return nil }
            switch kind {
            case .running, .walking, .hiking:
                return (distanceMeters / 0.78).rounded()
            default:
                return nil
            }
        }()

        return ActivitySample(
            id: deterministicUUID(localSeed),
            kind: kind,
            start: start,
            end: end,
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationMeters,
            stepCount: stepCount,
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

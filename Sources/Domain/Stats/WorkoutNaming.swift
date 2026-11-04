import Foundation

/// Which part of the day a workout belongs to.
enum TimeOfDay: String, CaseIterable, Sendable {
    case night
    case morning
    case afternoon
    case evening

    var adjective: String { rawValue }

    /// Night runs from 22:00 to 05:00, morning to noon, afternoon to 17:00.
    static func at(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> TimeOfDay {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
}

/// Names a workout the way a person would describe it:
/// "Your morning walk around Brtnice".
struct WorkoutNaming: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func title(for activity: ActivitySample, place: String?) -> String {
        let timeOfDay = TimeOfDay.at(activity.start, calendar: calendar)
        let noun = Self.noun(for: activity.kind)
        let base = "Your \(timeOfDay.adjective) \(noun)"

        guard let place = Self.cleanedPlace(place) else { return base }
        return "\(base) around \(place)"
    }

    /// Shorter variant for lists: "Morning walk around Brtnice".
    func shortTitle(for activity: ActivitySample, place: String?) -> String {
        let timeOfDay = TimeOfDay.at(activity.start, calendar: calendar)
        let noun = Self.noun(for: activity.kind)
        let base = "\(timeOfDay.adjective.capitalizedFirst) \(noun)"
        guard let place = Self.cleanedPlace(place) else { return base }
        return "\(base) around \(place)"
    }

    static func noun(for kind: ActivityKind) -> String {
        switch kind {
        case .running: return "run"
        case .walking: return "walk"
        case .cycling: return "ride"
        case .hiking: return "hike"
        case .swimming: return "swim"
        case .strength: return "strength workout"
        case .yoga: return "yoga session"
        case .other: return "workout"
        }
    }

    /// Placemark names arrive in different shapes; keep the settlement name.
    static func cleanedPlace(_ place: String?) -> String? {
        guard var place = place?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty else {
            return nil
        }
        // Reverse geocoding sometimes returns "Brtnice, Czechia" or a postcode prefix.
        if let comma = place.firstIndex(of: ",") {
            place = String(place[..<comma]).trimmingCharacters(in: .whitespaces)
        }
        place = place.replacingOccurrences(of: " okres", with: "")
        return place.isEmpty ? nil : place.capitalizedFirst
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

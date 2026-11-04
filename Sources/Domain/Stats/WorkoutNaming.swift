import Foundation

/// Which part of the day a workout belongs to.
enum TimeOfDay: String, CaseIterable, Sendable {
    case night
    case morning
    case afternoon
    case evening

    var adjective: String {
        switch self {
        case .night: return L10n.t(.namingNight)
        case .morning: return L10n.t(.namingMorning)
        case .afternoon: return L10n.t(.namingAfternoon)
        case .evening: return L10n.t(.namingEvening)
        }
    }

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

    /// "Your morning walk around Brtnice". The template is per language, so word
    /// order and any preposition live in the catalog, not here.
    func title(for activity: ActivitySample, place: String?) -> String {
        let timeOfDay = TimeOfDay.at(activity.start, calendar: calendar)
        let noun = Self.name(for: activity.kind)

        guard let place = Self.cleanedPlace(place) else {
            return L10n.t(.namingTitleNoPlace, timeOfDay.adjective, noun)
        }
        return L10n.t(.namingTitle, timeOfDay.adjective, noun, place)
    }

    /// Noun used inside a name: "walk" rather than the list title "Walk".
    static func name(for kind: ActivityKind) -> String {
        switch kind {
        case .running: return L10n.t(.nameRun)
        case .walking: return L10n.t(.nameWalk)
        case .cycling: return L10n.t(.nameRide)
        case .hiking: return L10n.t(.nameHike)
        case .swimming: return L10n.t(.nameSwim)
        case .strength: return L10n.t(.nameStrength)
        case .yoga: return L10n.t(.nameYoga)
        case .other: return L10n.t(.nameWorkout)
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

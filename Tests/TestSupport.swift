import Foundation
@testable import StatsWorkout

enum TestSupport {
    static func calendar(
        timeZone: String = "UTC",
        firstWeekday: Int = 2
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = firstWeekday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func date(
        _ calendar: Calendar,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func period(_ calendar: Calendar = TestSupport.calendar()) -> PeriodCalendar {
        PeriodCalendar(calendar: calendar)
    }
}

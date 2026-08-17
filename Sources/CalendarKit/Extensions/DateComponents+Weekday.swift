import Foundation

public extension DateComponents {
  /// Weekday numbers as Foundation reports them in `DateComponents.weekday`,
  /// where Sunday is `1` regardless of the calendar's first weekday.
  private enum DayOfWeek: Int {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1
  }

  /// Whether these components fall on a Monday.
  var isMonday: Bool {
    return weekday == DayOfWeek.monday.rawValue
  }

  /// Whether these components fall on a Tuesday.
  var isTuesday: Bool {
    return weekday == DayOfWeek.tuesday.rawValue
  }

  /// Whether these components fall on a Wednesday.
  var isWednesday: Bool {
    return weekday == DayOfWeek.wednesday.rawValue
  }

  /// Whether these components fall on a Thursday.
  var isThursday: Bool {
    return weekday == DayOfWeek.thursday.rawValue
  }

  /// Whether these components fall on a Friday.
  var isFriday: Bool {
    return weekday == DayOfWeek.friday.rawValue
  }

  /// Whether these components fall on a Saturday.
  var isSaturday: Bool {
    return weekday == DayOfWeek.saturday.rawValue
  }

  /// Whether these components fall on a Sunday.
  var isSunday: Bool {
    return weekday == DayOfWeek.sunday.rawValue
  }

  /// Whether these components fall on a Saturday or a Sunday.
  ///
  /// This is the Western weekend, not the calendar's or locale's own weekend
  /// definition. For locale-aware behavior use `Calendar.isDateInWeekend(_:)`.
  var isWeekend: Bool {
    return isSaturday || isSunday
  }
}

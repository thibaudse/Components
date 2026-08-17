import Foundation

public extension Calendar {
  /// Today, as fully populated `DateComponents` anchored to this calendar.
  ///
  /// This is the usual way to seed a ``CalendarView``:
  ///
  /// ```swift
  /// @State private var currentDay = Calendar.autoupdatingCurrent.today
  /// ```
  var today: DateComponents {
    return calendarDateComponents(from: .now)
  }

  /// Returns `DateComponents` containing every calendar component for a given date.
  ///
  /// `DateComponents` produced by `Calendar.dateComponents(_:from:)` only carries the
  /// components you asked for, and carries no calendar unless you request
  /// `.calendar`. CalendarKit's `DateComponents` helpers navigate and compare dates
  /// through the calendar attached to the components, so use this method whenever you
  /// convert a `Date` into components for a calendar view.
  ///
  /// - Parameter date: The date to extract components from.
  /// - Returns: Components carrying all available fields, including this calendar.
  func calendarDateComponents(from date: Date) -> DateComponents {
    return dateComponents(Calendar.Component.all, from: date)
  }

  /// The short weekday symbols, rotated so the calendar's own first weekday comes first.
  ///
  /// `shortWeekdaySymbols` always starts at Sunday. A calendar whose `firstWeekday`
  /// is Monday therefore needs the symbols rotated before they can label a grid:
  /// `["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]`.
  var localizedShortWeekdaySymbols: [String] {
    let symbols = shortWeekdaySymbols
    let firstIndex = firstWeekday - 1
    return Array(symbols[firstIndex...] + symbols[..<firstIndex])
  }

  /// The last weekday of the week, given the calendar's `firstWeekday`.
  ///
  /// For a calendar starting on Sunday (`1`) this is Saturday (`7`); for one starting
  /// on Monday (`2`) it is Sunday (`1`).
  var lastWeekday: Int {
    let last = firstWeekday - 1
    return last == 0 ? 7 : last
  }
}

extension Calendar.Component {
  /// Every component CalendarKit needs to round-trip a date through `DateComponents`.
  static var all: Set<Calendar.Component> {
    return [
      .era,
      .year,
      .month,
      .day,
      .weekday,
      .weekdayOrdinal,
      .quarter,
      .weekOfMonth,
      .weekOfYear,
      .yearForWeekOfYear,
      .calendar
    ]
  }
}

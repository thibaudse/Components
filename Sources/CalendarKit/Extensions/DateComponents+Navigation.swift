import Foundation

public extension DateComponents {
  /// Adds a value to one component, resolving the result through the attached calendar.
  ///
  /// Returns the receiver unchanged when the components carry no calendar or cannot
  /// form a date, so navigation can never silently produce a nonsense date.
  private func adding(component: Calendar.Component, value: Int) -> DateComponents {
    guard let calendar, let date else {
      return self
    }

    guard let newDate = calendar.date(byAdding: component, value: value, to: date) else {
      return self
    }

    return calendar.calendarDateComponents(from: newDate)
  }

  /// The same day one month earlier, clamped by the calendar for short months.
  var previousMonth: DateComponents {
    return adding(component: .month, value: -1)
  }

  /// The same day one month later, clamped by the calendar for short months.
  var nextMonth: DateComponents {
    return adding(component: .month, value: 1)
  }

  /// The same day one year earlier, clamped by the calendar on 29 February.
  var previousYear: DateComponents {
    return adding(component: .year, value: -1)
  }

  /// The same day one year later, clamped by the calendar on 29 February.
  var nextYear: DateComponents {
    return adding(component: .year, value: 1)
  }

  /// The day a given number of days before this one.
  /// - Parameter amount: How many days to step back. Defaults to `1`.
  func previousDays(_ amount: Int = 1) -> DateComponents {
    return adding(component: .day, value: -amount)
  }

  /// The day a given number of days after this one.
  /// - Parameter amount: How many days to step forward. Defaults to `1`.
  func nextDays(_ amount: Int = 1) -> DateComponents {
    return adding(component: .day, value: amount)
  }
}

import Foundation

public extension DateComponents {
  /// The number of empty leading cells before the first day of this month.
  ///
  /// A month whose first day falls on a Wednesday in a Monday-first calendar needs two
  /// blank cells before it. Returns `0` when the components carry no calendar, which
  /// lays the month out starting flush in the first column.
  var firstWeekdayOfMonth: Int {
    guard let firstDayWeekday = firstDayOfMonth.weekday,
          let calendarFirstWeekday = calendar?.firstWeekday
    else {
      return 0
    }
    return (firstDayWeekday - calendarFirstWeekday + 7) % 7
  }

  /// Every day number in this month, in order.
  ///
  /// For example `[1, 2, 3, … 30]` for a thirty-day month. Returns an empty array when
  /// the components carry no calendar or cannot form a date.
  var daysInMonth: [Int] {
    guard let calendar,
          let date,
          let range = calendar.range(of: .day, in: .month, for: date)
    else {
      return []
    }

    return Array(range)
  }

  /// The first day of this month, as fully populated components.
  var firstDayOfMonth: DateComponents {
    let components = with(day: 1)

    guard let calendar, let date = components.date else {
      return self
    }

    return calendar.calendarDateComponents(from: date)
  }

  /// The last day of this month, as fully populated components.
  ///
  /// Derived by stepping back one day from the first of the following month, so it is
  /// correct for short months and leap years alike.
  var lastDayOfMonth: DateComponents {
    let nextMonthFirstDay = nextMonth.firstDayOfMonth
    return nextMonthFirstDay.previousDays()
  }
}

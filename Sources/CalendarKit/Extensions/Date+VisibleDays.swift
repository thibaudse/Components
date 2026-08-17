import Foundation

public extension Date {
  /// A contiguous run of days centered on this date.
  ///
  /// Built for ``InlineCalendarView``, which draws whatever days you hand it:
  ///
  /// ```swift
  /// InlineCalendarView(visibleDays: Date.now.days(pastDays: 3, futureDays: 3))
  /// ```
  ///
  /// The dates keep this date's time of day; only the day component moves.
  ///
  /// - Parameters:
  ///   - pastDays: How many days before this date to include.
  ///   - futureDays: How many days after this date to include.
  ///   - calendar: The calendar used to step between days. Defaults to
  ///     `Calendar.autoupdatingCurrent`.
  /// - Returns: `pastDays + futureDays + 1` dates in ascending order, skipping any day
  ///   the calendar cannot form.
  func days(
    pastDays: Int,
    futureDays: Int,
    calendar: Calendar = .autoupdatingCurrent
  ) -> [Date] {
    guard pastDays >= 0, futureDays >= 0 else { return [] }

    return (-pastDays...futureDays).compactMap { dayOffset in
      calendar.date(byAdding: .day, value: dayOffset, to: self)
    }
  }
}

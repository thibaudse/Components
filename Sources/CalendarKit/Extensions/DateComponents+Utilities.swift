import Foundation

public extension DateComponents {
  /// Returns a copy with the given fields replaced, resolved through the attached calendar.
  ///
  /// Fields you omit keep their current value. The result is re-derived from a `Date`,
  /// so dependent fields such as `weekday` stay consistent:
  ///
  /// ```swift
  /// let firstOfMonth = currentDay.with(day: 1)
  /// ```
  ///
  /// Returns the receiver unchanged when the components carry no calendar or the
  /// requested combination cannot form a date.
  ///
  /// - Parameters:
  ///   - year: The year to use, or `nil` to keep the current one.
  ///   - month: The month to use, or `nil` to keep the current one.
  ///   - day: The day to use, or `nil` to keep the current one.
  func with(
    year: Int? = nil,
    month: Int? = nil,
    day: Int? = nil
  ) -> DateComponents {
    let component = DateComponents(
      calendar: calendar,
      year: year ?? self.year,
      month: month ?? self.month,
      day: day ?? self.day
    )

    guard let calendar, let date = component.date else { return self }

    return calendar.calendarDateComponents(from: date)
  }
}

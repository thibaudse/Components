import Foundation

/// One column heading of a ``CalendarView``, handed to ``CalendarView/calendarWeekdaySymbol(_:)``.
public struct CalendarWeekday: Hashable, Sendable {
  /// The short symbol for the day, localized by the calendar — "Mon", "lun.", "月".
  public let symbol: String

  /// The weekday as Foundation numbers them, where Sunday is `1` regardless of which day
  /// the calendar starts on.
  public let weekday: Int

  /// Whether this column is a Saturday or a Sunday.
  public var isWeekend: Bool {
    weekday == 1 || weekday == 7
  }

  init(symbol: String, weekday: Int) {
    self.symbol = symbol
    self.weekday = weekday
  }
}

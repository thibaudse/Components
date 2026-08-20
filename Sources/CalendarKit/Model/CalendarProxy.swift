import SwiftUI

/// The state and the navigation actions of a ``CalendarView``, handed to every toolbar
/// closure.
///
/// A calendar draws days and nothing else. Everything around it — a month title, chevrons,
/// a "Today" button, a year stepper, a segmented picker — is yours to build, and this is
/// what you build it from:
///
/// ```swift
/// CalendarView(currentDay: $currentDay)
///   .calendarToolbar { month in
///     HStack {
///       Text(month.monthTitle)
///       Spacer()
///       Button("Today", action: month.goToToday)
///         .disabled(month.containsToday)
///     }
///   }
/// ```
///
/// The proxy is rebuilt on every update, so its values always describe the month on
/// screen. Its actions write to the same binding the calendar was created with, which
/// means external changes and toolbar changes animate identically.
///
/// ## Topics
///
/// ### Reading the visible month
/// - ``currentDay``
/// - ``date``
/// - ``calendar``
/// - ``animation``
/// - ``year``
/// - ``month``
/// - ``monthTitle``
/// - ``monthName``
/// - ``yearTitle``
/// - ``weekdaySymbols``
/// - ``daysInMonth``
/// - ``firstDayOfMonth``
/// - ``lastDayOfMonth``
/// - ``containsToday``
///
/// ### Navigating
/// - ``goToPreviousMonth()``
/// - ``goToNextMonth()``
/// - ``goToPreviousYear()``
/// - ``goToNextYear()``
/// - ``goToToday()``
/// - ``go(to:)``
public struct CalendarProxy {
  /// The day the calendar is bound to: the anchor whose month is on screen.
  public let currentDay: DateComponents

  /// The calendar the view resolved its layout with — the one attached to
  /// ``currentDay``, or the fallback passed to ``CalendarView/init(currentDay:calendar:)``.
  public let calendar: Calendar

  /// The animation the calendar animates month changes with, as set by
  /// ``CalendarView/calendarAnimation(_:)`` — `nil` when month changes are instant.
  ///
  /// Scope your own chrome's animation with it, so a title or a badge moves on the same
  /// curve as the grid:
  ///
  /// ```swift
  /// Text(month.monthTitle)
  ///   .contentTransition(.numericText())
  ///   .animation(month.animation, value: month.monthTitle)
  /// ```
  public let animation: Animation?

  private let navigate: (DateComponents) -> Void

  init(
    currentDay: DateComponents,
    calendar: Calendar,
    animation: Animation?,
    navigate: @escaping (DateComponents) -> Void
  ) {
    self.currentDay = currentDay
    self.calendar = calendar
    self.animation = animation
    self.navigate = navigate
  }

  // MARK: - Reading the visible month

  /// ``currentDay`` as a `Date`, falling back to now if the components cannot form one.
  public var date: Date {
    currentDay.date ?? .now
  }

  /// The visible year, in the calendar's own era.
  public var year: Int? {
    currentDay.year
  }

  /// The visible month, `1` through `12` in a Gregorian calendar.
  public var month: Int? {
    currentDay.month
  }

  /// The month and year, formatted for the calendar's locale — "August 2026", "août 2026".
  public var monthTitle: String {
    formatted { $0.month(.wide).year() }
  }

  /// The month on its own, formatted for the calendar's locale — "August", "août".
  public var monthName: String {
    formatted { $0.month(.wide) }
  }

  /// The year on its own, formatted for the calendar's locale — "2026".
  public var yearTitle: String {
    formatted { $0.year() }
  }

  /// The short weekday symbols, ordered to match the grid's columns.
  public var weekdaySymbols: [String] {
    calendar.localizedShortWeekdaySymbols
  }

  /// Every day number in the visible month.
  public var daysInMonth: [Int] {
    currentDay.daysInMonth
  }

  /// The first day of the visible month.
  public var firstDayOfMonth: DateComponents {
    currentDay.firstDayOfMonth
  }

  /// The last day of the visible month.
  public var lastDayOfMonth: DateComponents {
    currentDay.lastDayOfMonth
  }

  /// Whether today falls inside the visible month — for disabling a "Today" button, or
  /// marking the current month in a picker.
  public var containsToday: Bool {
    guard let date = currentDay.date else { return false }
    return calendar.isDate(date, equalTo: .now, toGranularity: .month)
  }

  // MARK: - Navigating

  /// Moves to the same day one month earlier.
  public func goToPreviousMonth() {
    navigate(currentDay.previousMonth)
  }

  /// Moves to the same day one month later.
  public func goToNextMonth() {
    navigate(currentDay.nextMonth)
  }

  /// Moves to the same day one year earlier.
  public func goToPreviousYear() {
    navigate(currentDay.previousYear)
  }

  /// Moves to the same day one year later.
  public func goToNextYear() {
    navigate(currentDay.nextYear)
  }

  /// Moves to today, in the calendar the view is using.
  public func goToToday() {
    navigate(calendar.today)
  }

  /// Moves to an arbitrary day — for a date picker, a search result, a deep link.
  ///
  /// - Parameter day: The day to show. Components carrying no calendar are resolved
  ///   against ``calendar``.
  public func go(to day: DateComponents) {
    guard day.calendar == nil else {
      navigate(day)
      return
    }

    guard let date = calendar.date(from: day) else { return }
    navigate(calendar.calendarDateComponents(from: date))
  }

  private func formatted(_ style: (Date.FormatStyle) -> Date.FormatStyle) -> String {
    let base = Date.FormatStyle(
      locale: calendar.locale ?? .autoupdatingCurrent,
      calendar: calendar,
      timeZone: calendar.timeZone
    )
    return date.formatted(style(base)).localizedCapitalized
  }
}

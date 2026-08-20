import SwiftUI

/// A single row of days, sized to fit wherever you put it.
///
/// Where ``CalendarView`` owns a whole month, `InlineCalendarView` draws exactly the
/// days you hand it — a rolling week around today, the days of a streak, a sprint. It
/// is built for tight spaces such as widgets and list rows, so it has no header and no
/// navigation.
///
/// ```swift
/// InlineCalendarView(visibleDays: Date.now.days(pastDays: 3, futureDays: 3))
///   .calendarCell { date in
///     Text(Calendar.current.component(.day, from: date).formatted(.number))
///   }
///   .frame(width: 156)
/// ```
///
/// Days have no default appearance: without ``calendarCell(_:)`` you get the weekday
/// symbols above a row of empty squares. The symbols themselves are unstyled text, so
/// fonts and colors inherit from the environment — at widget sizes you will want to say
/// so explicitly.
///
/// ## Topics
///
/// ### Creating an inline calendar
/// - ``init(visibleDays:calendar:)``
///
/// ### Replacing what it draws
/// - ``calendarCell(_:)``
/// - ``calendarWeekdaySymbol(_:)``
/// - ``calendarWeekdays(_:)``
/// - ``CellStyle``
/// - ``WeekdayStyle``
///
/// ### Laying it out
/// - ``calendarSpacing(columns:weekdays:)``
///
/// ### Building a day range
/// - ``Foundation/Date/days(pastDays:futureDays:calendar:)``
public struct InlineCalendarView: View {
  /// A closure that builds the view for one visible day.
  public typealias CellStyle<Cell: View> = (_ date: Date) -> Cell

  /// A closure that builds the heading above one visible day.
  public typealias WeekdayStyle<Label: View> = (_ date: Date, _ weekday: CalendarWeekday) -> Label

  private var cellStyle: CellStyle<AnyView>?
  private var weekdayStyle: WeekdayStyle<AnyView>?
  private var weekdayVisibility: Visibility = .automatic

  private var columnSpacing: CGFloat = 0
  private var weekdaySpacing: CGFloat = 4

  private let visibleDays: [Date]
  private let calendar: Calendar

  /// Creates an inline calendar for a set of days.
  ///
  /// - Parameters:
  ///   - visibleDays: The days to draw, in the order they should appear. Each gets an
  ///     equal share of the available width. ``Foundation/Date/days(pastDays:futureDays:calendar:)``
  ///     builds a contiguous run for you.
  ///   - calendar: The calendar used to read the weekday of each day. Defaults to
  ///     `Calendar.autoupdatingCurrent`.
  public init(visibleDays: [Date], calendar: Calendar = .autoupdatingCurrent) {
    self.visibleDays = visibleDays
    self.calendar = calendar
  }

  public var body: some View {
    VStack(spacing: weekdaySpacing) {
      if weekdayVisibility != .hidden {
        InlineCalendarWeekdays(
          visibleDays: visibleDays,
          calendar: calendar,
          columnSpacing: columnSpacing,
          weekdayStyle: weekdayStyle
        )
      }

      InlineCalendarDays(
        visibleDays: visibleDays,
        columnSpacing: columnSpacing,
        cellStyle: cellStyle
      )
    }
  }

  /// Sets the view drawn for each visible day.
  ///
  /// Called once per day in ``init(visibleDays:calendar:)``. Each cell is laid out in a
  /// square that shares the row width equally.
  ///
  /// - Parameter cell: A closure receiving the day's date and returning its view.
  public func calendarCell(@ViewBuilder _ cell: @escaping CellStyle<some View>) -> Self {
    var copy = self
    copy.cellStyle = { date in
      AnyView(cell(date))
    }
    return copy
  }

  /// Replaces the headings above the days with views of your own.
  ///
  /// Called once per visible day, with that day's date and its ``CalendarWeekday`` — so a
  /// heading can read "TODAY", or mark weekends, without recomputing the symbol.
  ///
  /// - Parameter weekday: A closure receiving the date and its weekday, returning the
  ///   heading.
  public func calendarWeekdaySymbol(@ViewBuilder _ weekday: @escaping WeekdayStyle<some View>) -> Self {
    var copy = self
    copy.weekdayStyle = { date, value in
      AnyView(weekday(date, value))
    }
    return copy
  }

  /// Shows or hides the row of headings.
  ///
  /// - Parameter visibility: `.hidden` removes the row, leaving only the days; anything
  ///   else keeps it.
  public func calendarWeekdays(_ visibility: Visibility) -> Self {
    var copy = self
    copy.weekdayVisibility = visibility
    return copy
  }

  /// Sets the gaps the row leaves between its own parts.
  ///
  /// Omitted values keep their defaults: 0 between columns, 4 between the headings and the
  /// days.
  ///
  /// - Parameters:
  ///   - columns: The horizontal gap between days, applied to the headings too.
  ///   - weekdays: The gap between the headings and the days.
  public func calendarSpacing(columns: CGFloat? = nil, weekdays: CGFloat? = nil) -> Self {
    var copy = self
    copy.columnSpacing = columns ?? columnSpacing
    copy.weekdaySpacing = weekdays ?? weekdaySpacing
    return copy
  }
}

private struct InlineCalendarWeekdays: View {
  let visibleDays: [Date]
  let calendar: Calendar
  let columnSpacing: CGFloat
  let weekdayStyle: InlineCalendarView.WeekdayStyle<AnyView>?

  var body: some View {
    HStack(spacing: columnSpacing) {
      ForEach(visibleDays, id: \.self) { date in
        if let weekdayStyle {
          weekdayStyle(date, weekday(for: date))
            .frame(maxWidth: .infinity)
        } else {
          Text(verbatim: weekday(for: date).symbol)
            .frame(maxWidth: .infinity)
        }
      }
    }
    .accessibilityHidden(true)
  }

  private func weekday(for date: Date) -> CalendarWeekday {
    let weekday = calendar.component(.weekday, from: date)
    let symbols = calendar.shortWeekdaySymbols
    let index = weekday - 1

    return CalendarWeekday(
      symbol: symbols.indices.contains(index) ? symbols[index] : "",
      weekday: weekday
    )
  }
}

private struct InlineCalendarDays: View {
  let visibleDays: [Date]
  let columnSpacing: CGFloat
  let cellStyle: InlineCalendarView.CellStyle<AnyView>?

  var body: some View {
    HStack(spacing: columnSpacing) {
      ForEach(visibleDays, id: \.self) { date in
        Color.clear
          .aspectRatio(1, contentMode: .fit)
          .overlay {
            if let cellStyle {
              cellStyle(date)
                .frame(maxWidth: .infinity)
            }
          }
      }
    }
  }
}

#Preview {
  InlineCalendarView(visibleDays: Date.now.days(pastDays: 3, futureDays: 2))
    .calendarWeekdaySymbol { _, weekday in
      Text(verbatim: weekday.symbol.localizedUppercase)
        .font(.system(size: 7, weight: .medium))
        .foregroundStyle(.white.opacity(0.4))
    }
    .calendarCell { date in
      Text(verbatim: Calendar.autoupdatingCurrent.component(.day, from: date).formatted(.number))
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.white)
    }
    .frame(width: 156)
    .padding()
    .background(Color.black)
}

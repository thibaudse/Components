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
/// - ``init(visibleDays:)``
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
/// - ``calendarCellAspectRatio(_:)``
///
/// ### Tuning rendering
/// - ``calendarDrawingGroup(_:)``
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

  private var cellAspectRatio: CGFloat? = 1
  private var columnSpacing: CGFloat = 0
  private var weekdaySpacing: CGFloat = 4
  private var usesDrawingGroup = true

  private let visibleDays: [Date]

  /// SwiftUI's own calendar environment value, used to read each day's weekday.
  @Environment(\.calendar) private var calendar

  /// Creates an inline calendar for a set of days.
  ///
  /// The calendar used to read each day's weekday comes from the environment — set
  /// `\.calendar` to change it.
  ///
  /// - Parameter visibleDays: The days to draw, in the order they should appear. Each gets
  ///   an equal share of the available width.
  ///   ``Foundation/Date/days(pastDays:futureDays:calendar:)`` builds a contiguous run for
  ///   you.
  public init(visibleDays: [Date]) {
    self.visibleDays = visibleDays
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
        // Decoration when the view drew it; the caller's business when they did.
        .accessibilityHidden(weekdayStyle == nil)
      }

      InlineCalendarDays(
        visibleDays: visibleDays,
        cellAspectRatio: cellAspectRatio,
        columnSpacing: columnSpacing,
        cellStyle: cellStyle
      )
      .modifier(OptionalDrawingGroup(isEnabled: usesDrawingGroup))
    }
  }

  /// Sets the view drawn for each visible day.
  ///
  /// Called once per day in ``init(visibleDays:)``. Each cell is laid out in a square that
  /// shares the row width equally.
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

  /// Sets the shape of each day's cell.
  ///
  /// `1` — the default — makes each day a square sharing the row width equally. Pass
  /// another ratio for wider or taller cells, or `nil` to let the content decide the
  /// height, which is what a row of pills or stacked labels wants.
  ///
  /// - Parameter ratio: Width divided by height, or `nil` to size by content.
  public func calendarCellAspectRatio(_ ratio: CGFloat?) -> Self {
    var copy = self
    copy.cellAspectRatio = ratio
    return copy
  }

  /// Controls whether the row of days is rendered into an offscreen image before it is
  /// drawn.
  ///
  /// On by default. Turn it off when a cell needs effects that cannot survive being
  /// rasterized — a `Material` background, vibrancy, or a shadow falling outside the
  /// cell's bounds.
  ///
  /// - Parameter isEnabled: Whether to flatten the row. Defaults to `true`.
  public func calendarDrawingGroup(_ isEnabled: Bool = true) -> Self {
    var copy = self
    copy.usesDrawingGroup = isEnabled
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
  let cellAspectRatio: CGFloat?
  let columnSpacing: CGFloat
  let cellStyle: InlineCalendarView.CellStyle<AnyView>?

  var body: some View {
    HStack(spacing: columnSpacing) {
      ForEach(visibleDays, id: \.self) { date in
        CalendarCellContainer(aspectRatio: cellAspectRatio) {
          if let cellStyle {
            cellStyle(date)
          } else {
            Color.clear
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

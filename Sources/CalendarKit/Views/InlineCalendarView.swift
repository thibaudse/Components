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
/// symbols above a row of empty squares.
///
/// ## Topics
///
/// ### Creating an inline calendar
/// - ``init(visibleDays:calendar:)``
///
/// ### Styling days
/// - ``calendarCell(_:)``
/// - ``CellStyle``
///
/// ### Building a day range
/// - ``Foundation/Date/days(pastDays:futureDays:calendar:)``
public struct InlineCalendarView: View {
  /// A closure that builds the view for one visible day.
  public typealias CellStyle<Cell: View> = (_ date: Date) -> Cell

  private var cellStyle: CellStyle<AnyView>?

  private let visibleDays: [Date]
  private let calendar: Calendar

  @Environment(\.calendarTheme) private var theme

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
    VStack(spacing: theme.metrics.weekdayRowSpacing) {
      InlineCalendarWeekdays(
        visibleDays: visibleDays,
        calendar: calendar
      )

      InlineCalendarDays(
        visibleDays: visibleDays,
        cellStyle: cellStyle
      )
      .drawingGroup()
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
}

private struct InlineCalendarWeekdays: View {
  let visibleDays: [Date]
  let calendar: Calendar

  @Environment(\.calendarTheme) private var theme

  var body: some View {
    HStack(spacing: theme.metrics.inlineWeekdaySpacing) {
      ForEach(visibleDays, id: \.self) { date in
        Text(verbatim: symbol(for: date))
          .font(theme.fonts.inlineWeekdaySymbol)
          .textCase(.uppercase)
          .foregroundStyle(theme.colors.weekdaySymbol)
          .frame(maxWidth: .infinity)
      }
    }
    .accessibilityHidden(true)
  }

  private func symbol(for date: Date) -> String {
    let weekday = calendar.component(.weekday, from: date)
    let symbols = calendar.shortWeekdaySymbols
    let index = weekday - 1

    guard symbols.indices.contains(index) else { return "" }

    return symbols[index]
  }
}

private struct InlineCalendarDays: View {
  let visibleDays: [Date]
  let cellStyle: InlineCalendarView.CellStyle<AnyView>?

  var body: some View {
    HStack(spacing: 0) {
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
    .calendarCell { date in
      Text(verbatim: Calendar.autoupdatingCurrent.component(.day, from: date).formatted(.number))
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.white)
    }
    .frame(width: 156)
    .padding()
    .background(Color.black)
    .calendarTheme(.dark)
}

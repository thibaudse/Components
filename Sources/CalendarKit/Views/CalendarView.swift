import SwiftUI

/// A month grid, and nothing else.
///
/// The calendar draws days. It does not draw a title, chevrons, or any other chrome —
/// those are yours, added as toolbars and given everything they need through a
/// ``CalendarProxy``:
///
/// ```swift
/// struct MonthView: View {
///   @State private var currentDay = Calendar.autoupdatingCurrent.today
///
///   var body: some View {
///     CalendarView(currentDay: $currentDay)
///       .calendarToolbar { month in
///         HStack {
///           Text(month.monthTitle)
///             .font(.headline)
///
///           Spacer()
///
///           Button("Previous", systemImage: "chevron.left", action: month.goToPreviousMonth)
///           Button("Next", systemImage: "chevron.right", action: month.goToNextMonth)
///         }
///       }
///       .calendarCell { day in
///         Text(day.day?.formatted(.number) ?? "")
///       }
///   }
/// }
/// ```
///
/// The `currentDay` binding is both the month on screen and the anchor day inside it.
/// Whatever moves it — a toolbar button, a date picker elsewhere in your app, a deep link
/// — slides the grid in the direction of travel.
///
/// ## Topics
///
/// ### Creating a calendar
/// - ``init(currentDay:calendar:)``
///
/// ### Adding chrome
/// - ``calendarToolbar(_:content:)``
/// - ``CalendarProxy``
/// - ``CalendarToolbarPlacement``
///
/// ### Styling the grid
/// - ``calendarCell(_:)``
/// - ``calendarWeekdaySymbol(_:)``
/// - ``calendarWeekdays(_:)``
/// - ``CalendarWeekday``
public struct CalendarView: View {
  /// A closure building the view for one day of the visible month.
  ///
  /// The components are fully populated and carry the calendar, so `day.day`,
  /// `day.weekday`, and helpers such as ``Foundation/DateComponents/isWeekend`` are all
  /// available.
  public typealias CellStyle<Cell: View> = (_ dateComponents: DateComponents) -> Cell

  /// A closure building the view for one column heading.
  public typealias WeekdayStyle<Label: View> = (_ weekday: CalendarWeekday) -> Label

  /// A closure building one toolbar row from the calendar's state and actions.
  public typealias ToolbarContent<Content: View> = (_ month: CalendarProxy) -> Content

  private struct Toolbar: Identifiable {
    let id = UUID()
    let placement: CalendarToolbarPlacement
    let content: ToolbarContent<AnyView>
  }

  private var cellStyle: CellStyle<AnyView>?
  private var weekdayStyle: WeekdayStyle<AnyView>?
  private var weekdayVisibility: Visibility = .automatic
  private var toolbars: [Toolbar] = []

  private let fallbackCalendar: Calendar

  @Binding private var currentDay: DateComponents

  @Environment(\.calendarTheme) private var theme

  @State private var navigationDirection: NavigationDirection?

  /// Creates a calendar bound to the day it should show.
  ///
  /// - Parameters:
  ///   - currentDay: The day whose month is displayed. Seed it with
  ///     ``Foundation/Calendar/today`` so the components carry a calendar.
  ///   - calendar: The calendar used when `currentDay` carries none of its own.
  ///     Defaults to `Calendar.autoupdatingCurrent`. A calendar attached to
  ///     `currentDay` always wins, so this is only a fallback.
  public init(currentDay: Binding<DateComponents>, calendar: Calendar = .autoupdatingCurrent) {
    _currentDay = currentDay
    fallbackCalendar = calendar
  }

  /// The day being displayed, guaranteed to carry a calendar.
  private var day: DateComponents {
    guard currentDay.calendar == nil else { return currentDay }

    let date = fallbackCalendar.date(from: currentDay) ?? .now
    return fallbackCalendar.calendarDateComponents(from: date)
  }

  private var calendar: Calendar {
    day.calendar ?? fallbackCalendar
  }

  private var proxy: CalendarProxy {
    CalendarProxy(currentDay: day, calendar: calendar) { target in
      navigate(to: target)
    }
  }

  public var body: some View {
    VStack(spacing: theme.metrics.toolbarSpacing) {
      toolbarRows(for: .above)

      VStack(spacing: theme.metrics.weekdayRowSpacing) {
        if weekdayVisibility != .hidden {
          CalendarWeekdays(calendar: calendar, weekdayStyle: weekdayStyle)
        }

        CalendarGrid(currentDay: day, cellStyle: cellStyle)
          .drawingGroup()
          .id(day.month)
          .transition(.month(direction: navigationDirection))
      }

      toolbarRows(for: .below)
    }
    .padding(theme.metrics.contentInsets)
  }

  @ViewBuilder
  private func toolbarRows(for placement: CalendarToolbarPlacement) -> some View {
    let rows = toolbars.filter { $0.placement == placement }

    if !rows.isEmpty {
      let proxy = proxy

      VStack(spacing: theme.metrics.toolbarSpacing) {
        ForEach(rows) { row in
          row.content(proxy)
        }
      }
    }
  }

  private func navigate(to target: DateComponents) {
    let direction = NavigationDirection(from: day, to: target)

    Task {
      navigationDirection = direction
      // Small delay to ensure the view picks up the direction before the transition runs.
      try? await Task.sleep(for: .seconds(0.01))
      withAnimation(.snappy(duration: 0.3)) {
        currentDay = target
      }
    }
  }

  // MARK: - Adding chrome

  /// Adds a row of your own views above or below the grid, built from the calendar's
  /// state and actions.
  ///
  /// This is where a month title, navigation controls, a year stepper, or a legend go.
  /// Apply it more than once to stack rows; each keeps the placement it was given.
  ///
  /// ```swift
  /// CalendarView(currentDay: $currentDay)
  ///   .calendarToolbar { month in
  ///     Text(month.monthTitle)
  ///   }
  ///   .calendarToolbar(.below) { month in
  ///     Button("Today", action: month.goToToday)
  ///       .disabled(month.containsToday)
  ///   }
  /// ```
  ///
  /// - Parameters:
  ///   - placement: Whether the row sits ``CalendarToolbarPlacement/above`` the weekday
  ///     symbols or ``CalendarToolbarPlacement/below`` the grid. Defaults to `.above`.
  ///   - content: A closure receiving the calendar's ``CalendarProxy`` and returning the
  ///     row's content.
  public func calendarToolbar(
    _ placement: CalendarToolbarPlacement = .above,
    @ViewBuilder content: @escaping ToolbarContent<some View>
  ) -> Self {
    var copy = self
    copy.toolbars.append(
      Toolbar(placement: placement) { proxy in
        AnyView(content(proxy))
      }
    )
    return copy
  }

  // MARK: - Styling the grid

  /// Replaces the default day number with a view of your own.
  ///
  /// Called once per day of the visible month. Each cell is laid out in a square that
  /// shares the grid width equally, so size content relative to that square rather than
  /// assuming a fixed point size.
  ///
  /// - Parameter cell: A closure receiving the day's components and returning its view.
  public func calendarCell(@ViewBuilder _ cell: @escaping CellStyle<some View>) -> Self {
    var copy = self
    copy.cellStyle = { dateComponents in
      AnyView(cell(dateComponents))
    }
    return copy
  }

  /// Replaces the column headings with views of your own.
  ///
  /// Called once per column, in the order the grid draws them — already rotated to the
  /// calendar's first weekday.
  ///
  /// - Parameter weekday: A closure receiving the column's ``CalendarWeekday`` and
  ///   returning its label.
  public func calendarWeekdaySymbol(@ViewBuilder _ weekday: @escaping WeekdayStyle<some View>) -> Self {
    var copy = self
    copy.weekdayStyle = { value in
      AnyView(weekday(value))
    }
    return copy
  }

  /// Shows or hides the column headings.
  ///
  /// Hide them when a toolbar of your own already labels the columns, or when the
  /// calendar is small enough that they would not be legible.
  ///
  /// - Parameter visibility: `.hidden` removes the row; anything else keeps it.
  public func calendarWeekdays(_ visibility: Visibility) -> Self {
    var copy = self
    copy.weekdayVisibility = visibility
    return copy
  }
}

private struct CalendarWeekdays: View {
  let calendar: Calendar
  let weekdayStyle: CalendarView.WeekdayStyle<AnyView>?

  @Environment(\.calendarTheme) private var theme

  private var weekdays: [CalendarWeekday] {
    calendar.localizedShortWeekdaySymbols.enumerated().map { offset, symbol in
      CalendarWeekday(
        symbol: symbol,
        weekday: (calendar.firstWeekday - 1 + offset) % 7 + 1
      )
    }
  }

  var body: some View {
    Grid(horizontalSpacing: 0) {
      GridRow {
        ForEach(weekdays, id: \.self) { weekday in
          if let weekdayStyle {
            weekdayStyle(weekday)
              .frame(maxWidth: .infinity)
          } else {
            Text(verbatim: weekday.symbol.localizedUppercase)
              .font(theme.fonts.weekdaySymbol)
              .foregroundStyle(theme.colors.weekdaySymbol)
              .frame(maxWidth: .infinity)
          }
        }
      }
    }
    .accessibilityHidden(true)
  }
}

private struct CalendarGrid: View {
  let currentDay: DateComponents
  let cellStyle: CalendarView.CellStyle<AnyView>?

  @Environment(\.calendarTheme) private var theme

  private var firstDayWeekday: Int {
    return currentDay.firstWeekdayOfMonth
  }

  private var totalCells: Int {
    return firstDayWeekday + currentDay.daysInMonth.count
  }

  private var numberOfRows: Int {
    return Int(ceil(Double(totalCells) / 7.0))
  }

  var body: some View {
    Grid(horizontalSpacing: 0, verticalSpacing: theme.metrics.dayRowSpacing) {
      ForEach(0..<numberOfRows, id: \.self) { row in
        GridRow {
          ForEach(0..<7, id: \.self) { column in
            let index = row * 7 + column
            Color.clear
              .aspectRatio(1, contentMode: .fit)
              .overlay {
                if index >= firstDayWeekday, index < totalCells {
                  let day = index - firstDayWeekday + 1
                  let component = currentDay.with(day: day)

                  if let cellStyle {
                    cellStyle(component)
                  } else {
                    Text(verbatim: day.formatted(.number))
                      .font(theme.fonts.dayNumber)
                      .foregroundStyle(theme.colors.dayNumber)
                  }
                }
              }
              .frame(maxWidth: .infinity)
          }
        }
      }
    }
  }
}

#Preview("Grid only") {
  @Previewable @State var currentDay = Calendar.autoupdatingCurrent.today

  CalendarView(currentDay: $currentDay)
    .padding()
}

#Preview("With a month toolbar") {
  @Previewable @State var currentDay = Calendar.autoupdatingCurrent.today

  CalendarView(currentDay: $currentDay)
    .calendarToolbar { month in
      CalendarMonthHeader(month)
    }
    .calendarToolbar(.below) { month in
      Button("Today", action: month.goToToday)
        .disabled(month.containsToday)
        .font(.footnote)
    }
    .padding()
}

#Preview("Toolbars and cells of your own") {
  @Previewable @State var currentDay = Calendar.autoupdatingCurrent.today

  CalendarView(currentDay: $currentDay)
    .calendarToolbar { month in
      HStack(spacing: 12) {
        Button("Previous year", systemImage: "chevron.left.2", action: month.goToPreviousYear)
          .labelStyle(.iconOnly)

        Text(verbatim: month.monthName)
          .font(.system(size: 20, weight: .bold, design: .rounded))

        Text(verbatim: month.yearTitle)
          .font(.system(size: 20, weight: .light, design: .rounded))
          .foregroundStyle(.secondary)

        Spacer()

        Button("Next year", systemImage: "chevron.right.2", action: month.goToNextYear)
          .labelStyle(.iconOnly)
      }
    }
    .calendarWeekdaySymbol { weekday in
      Text(verbatim: weekday.symbol.prefix(1).localizedUppercase)
        .font(.footnote.weight(.bold))
        .foregroundStyle(weekday.isWeekend ? .tertiary : .secondary)
    }
    .calendarCell { day in
      Text(verbatim: day.day?.formatted(.number) ?? "")
        .font(.system(size: 17, weight: .medium, design: .rounded))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
          if day.isWeekend {
            Circle().fill(.quaternary)
          }
        }
    }
    .padding()
}

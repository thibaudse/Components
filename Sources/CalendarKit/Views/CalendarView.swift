import SwiftUI

/// A month grid, and nothing else.
///
/// The calendar decides *where* things go — which square each day belongs in, how many
/// rows the month needs, which column starts the week. Everything about how they *look*
/// is yours: it draws unstyled text, so fonts and colors inherit from the environment
/// like any other SwiftUI view, and each part has a modifier to replace it outright.
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
///           Spacer()
///           Button("Previous", systemImage: "chevron.left", action: month.goToPreviousMonth)
///           Button("Next", systemImage: "chevron.right", action: month.goToNextMonth)
///         }
///       }
///       .calendarCell { day in
///         Text(day.day?.formatted(.number) ?? "")
///       }
///       .font(.callout)              // ordinary SwiftUI modifiers still apply
///       .foregroundStyle(.primary)
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
/// ### Replacing what it draws
/// - ``calendarCell(_:)``
/// - ``calendarWeekdaySymbol(_:)``
/// - ``calendarWeekdays(_:)``
/// - ``CalendarWeekday``
///
/// ### Laying it out
/// - ``calendarSpacing(rows:columns:weekdays:toolbars:)``
///
/// ### Animating month changes
/// - ``calendarAnimation(_:)``
/// - ``calendarTransition(_:)``
/// - ``CalendarNavigationDirection``
///
/// ### Tuning rendering
/// - ``calendarDrawingGroup(_:)``
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

  private var rowSpacing: CGFloat = 8
  private var columnSpacing: CGFloat = 0
  private var weekdaySpacing: CGFloat = 4
  private var toolbarSpacing: CGFloat = 12

  private var animation: Animation? = .snappy(duration: 0.3)
  private var transition: ((CalendarNavigationDirection) -> AnyTransition)?
  private var usesDrawingGroup = true

  private let fallbackCalendar: Calendar

  @Binding private var currentDay: DateComponents

  @State private var navigationDirection: CalendarNavigationDirection?

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

  /// `.identity` until the first navigation, so the calendar does not animate in from an
  /// arbitrary edge when it first appears.
  private var monthTransition: AnyTransition {
    guard let navigationDirection else { return .identity }
    return transition?(navigationDirection) ?? .month(direction: navigationDirection)
  }

  public var body: some View {
    VStack(spacing: toolbarSpacing) {
      toolbarRows(for: .above)

      VStack(spacing: weekdaySpacing) {
        if weekdayVisibility != .hidden {
          CalendarWeekdays(
            calendar: calendar,
            columnSpacing: columnSpacing,
            weekdayStyle: weekdayStyle
          )
        }

        CalendarGrid(
          currentDay: day,
          rowSpacing: rowSpacing,
          columnSpacing: columnSpacing,
          cellStyle: cellStyle
        )
        .modifier(OptionalDrawingGroup(isEnabled: usesDrawingGroup))
        .id(day.month)
        .transition(monthTransition)
      }

      toolbarRows(for: .below)
    }
  }

  @ViewBuilder
  private func toolbarRows(for placement: CalendarToolbarPlacement) -> some View {
    let rows = toolbars.filter { $0.placement == placement }

    if !rows.isEmpty {
      let proxy = proxy

      VStack(spacing: toolbarSpacing) {
        ForEach(rows) { row in
          row.content(proxy)
        }
      }
    }
  }

  private func navigate(to target: DateComponents) {
    let direction = CalendarNavigationDirection(from: day, to: target)

    guard let animation else {
      navigationDirection = direction
      currentDay = target
      return
    }

    Task {
      navigationDirection = direction
      // Small delay to ensure the view picks up the direction before the transition runs.
      try? await Task.sleep(for: .seconds(0.01))
      withAnimation(animation) {
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

  // MARK: - Replacing what it draws

  /// Replaces the day number with a view of your own.
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

  /// Shows or hides the row of column headings.
  ///
  /// - Parameter visibility: `.hidden` removes the row; anything else keeps it.
  public func calendarWeekdays(_ visibility: Visibility) -> Self {
    var copy = self
    copy.weekdayVisibility = visibility
    return copy
  }

  // MARK: - Laying it out

  /// Sets the gaps the calendar leaves between its own parts.
  ///
  /// Omitted values keep their defaults: 8 between rows of days, 0 between columns, 4
  /// between the weekday row and the grid, 12 between toolbar rows. The calendar adds no
  /// padding around itself — use `padding(_:)` for that.
  ///
  /// - Parameters:
  ///   - rows: The vertical gap between rows of days.
  ///   - columns: The horizontal gap between columns, applied to the weekday row and the
  ///     grid alike.
  ///   - weekdays: The gap between the weekday row and the first row of days.
  ///   - toolbars: The gap between toolbar rows, and between a toolbar and the grid.
  public func calendarSpacing(
    rows: CGFloat? = nil,
    columns: CGFloat? = nil,
    weekdays: CGFloat? = nil,
    toolbars: CGFloat? = nil
  ) -> Self {
    var copy = self
    copy.rowSpacing = rows ?? rowSpacing
    copy.columnSpacing = columns ?? columnSpacing
    copy.weekdaySpacing = weekdays ?? weekdaySpacing
    copy.toolbarSpacing = toolbars ?? toolbarSpacing
    return copy
  }

  // MARK: - Animating month changes

  /// Sets the animation used when the month changes.
  ///
  /// Defaults to `.snappy(duration: 0.3)`. Pass `nil` to change months instantly.
  ///
  /// - Parameter animation: The animation to run, or `nil` for none.
  public func calendarAnimation(_ animation: Animation?) -> Self {
    var copy = self
    copy.animation = animation
    return copy
  }

  /// Replaces the transition the grid uses when the month changes.
  ///
  /// The default slides in the direction of travel, blurring and fading as it goes. The
  /// closure receives that direction, so an asymmetric transition can be built either way
  /// round:
  ///
  /// ```swift
  /// CalendarView(currentDay: $currentDay)
  ///   .calendarTransition { direction in
  ///     .push(from: direction == .forward ? .trailing : .leading)
  ///   }
  /// ```
  ///
  /// - Parameter transition: A closure receiving the direction of travel and returning
  ///   the transition to use.
  public func calendarTransition(
    _ transition: @escaping (CalendarNavigationDirection) -> AnyTransition
  ) -> Self {
    var copy = self
    copy.transition = transition
    return copy
  }

  // MARK: - Tuning rendering

  /// Controls whether the grid is rendered into an offscreen image before it is drawn.
  ///
  /// On by default, and worth leaving on: flattening the grid into one layer measurably
  /// smooths the month transition, which animates every cell at once.
  ///
  /// The cost is that your cells are rasterized along with the rest. Turn it off when a
  /// cell needs effects that cannot survive that — a `Material` background, vibrancy, a
  /// shadow that falls outside the cell's bounds:
  ///
  /// ```swift
  /// CalendarView(currentDay: $currentDay)
  ///   .calendarCell { day in
  ///     DayCell(day: day)   // draws a .regularMaterial background
  ///   }
  ///   .calendarDrawingGroup(false)
  /// ```
  ///
  /// - Parameter isEnabled: Whether to flatten the grid. Defaults to `true`.
  public func calendarDrawingGroup(_ isEnabled: Bool = true) -> Self {
    var copy = self
    copy.usesDrawingGroup = isEnabled
    return copy
  }
}

private struct CalendarWeekdays: View {
  let calendar: Calendar
  let columnSpacing: CGFloat
  let weekdayStyle: CalendarView.WeekdayStyle<AnyView>?

  private var weekdays: [CalendarWeekday] {
    calendar.localizedShortWeekdaySymbols.enumerated().map { offset, symbol in
      CalendarWeekday(
        symbol: symbol,
        weekday: (calendar.firstWeekday - 1 + offset) % 7 + 1
      )
    }
  }

  var body: some View {
    Grid(horizontalSpacing: columnSpacing) {
      GridRow {
        ForEach(weekdays, id: \.self) { weekday in
          if let weekdayStyle {
            weekdayStyle(weekday)
              .frame(maxWidth: .infinity)
          } else {
            Text(verbatim: weekday.symbol)
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
  let rowSpacing: CGFloat
  let columnSpacing: CGFloat
  let cellStyle: CalendarView.CellStyle<AnyView>?

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
    Grid(horizontalSpacing: columnSpacing, verticalSpacing: rowSpacing) {
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

#Preview("Unstyled") {
  @Previewable @State var currentDay = Calendar.autoupdatingCurrent.today

  CalendarView(currentDay: $currentDay)
    .padding()
}

#Preview("Styled by inheritance") {
  @Previewable @State var currentDay = Calendar.autoupdatingCurrent.today

  CalendarView(currentDay: $currentDay)
    .calendarToolbar { month in
      CalendarMonthHeader(month)
    }
    .calendarWeekdaySymbol { weekday in
      Text(verbatim: weekday.symbol.localizedUppercase)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .font(.system(size: 17, weight: .medium))
    .padding()
}

#Preview("Fully custom") {
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
    .calendarSpacing(rows: 12, weekdays: 8)
    .calendarAnimation(.bouncy)
    .padding()
}

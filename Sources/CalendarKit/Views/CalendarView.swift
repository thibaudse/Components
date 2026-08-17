import SwiftUI

/// A month grid with a header that pages between months.
///
/// `CalendarView` draws the chrome — the month title, the navigation chevrons, the
/// weekday symbols, and a square grid of day cells — and hands each day back to you as
/// `DateComponents` so you decide what a day looks like:
///
/// ```swift
/// struct MonthPicker: View {
///   @State private var currentDay = Calendar.autoupdatingCurrent.today
///   @State private var selection: DateComponents?
///
///   var body: some View {
///     CalendarView(currentDay: $currentDay)
///       .withCellStyle { day in
///         Button {
///           selection = day
///         } label: {
///           Text(day.day?.formatted(.number) ?? "")
///             .foregroundStyle(day == selection ? .white : .primary)
///         }
///       }
///   }
/// }
/// ```
///
/// The `currentDay` binding is both the month on screen and the anchor day inside it.
/// Tapping a chevron writes the same day in the neighbouring month back to the binding,
/// which is what drives the sliding transition.
///
/// ## Topics
///
/// ### Creating a calendar
/// - ``init(currentDay:calendar:)``
///
/// ### Styling days
/// - ``withCellStyle(_:)``
/// - ``CellStyle``
///
/// ### Configuring the header
/// - ``withMonthTitle(_:)``
/// - ``backwardDisabled(_:)``
/// - ``forwardDisabled(_:)``
public struct CalendarView: View {
  /// A closure that builds the view for one day of the month.
  ///
  /// The components passed in are fully populated and carry the calendar, so
  /// `day.day`, `day.weekday`, and helpers such as ``Foundation/DateComponents/isWeekend``
  /// are all available.
  public typealias CellStyle<Cell: View> = (_ dateComponents: DateComponents) -> Cell

  private var cellStyle: CellStyle<AnyView>?
  private var monthTitle: ((Date) -> String)?
  private var backwardDisabled = false
  private var forwardDisabled = false

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
  ///
  /// Every date helper resolves through the calendar attached to the components, so a
  /// binding seeded with bare `DateComponents(year:month:day:)` would otherwise lay out
  /// an empty month.
  private var day: DateComponents {
    guard currentDay.calendar == nil else { return currentDay }

    let date = fallbackCalendar.date(from: currentDay) ?? .now
    return fallbackCalendar.calendarDateComponents(from: date)
  }

  public var body: some View {
    VStack(spacing: theme.metrics.headerSpacing) {
      CalendarHeader(
        title: title,
        backwardDisabled: backwardDisabled,
        forwardDisabled: forwardDisabled
      )
      .onGoBackward {
        navigateMonth(to: .backward)
      }
      .onGoForward {
        navigateMonth(to: .forward)
      }

      VStack(spacing: theme.metrics.weekdayRowSpacing) {
        CalendarWeekdays(calendar: day.calendar ?? fallbackCalendar)

        CalendarGrid(currentDay: day, cellStyle: cellStyle)
          .drawingGroup()
          .id(day.month)
          .transition(.month(direction: navigationDirection))
      }
    }
    .padding(theme.metrics.contentInsets)
  }

  private var title: String {
    let day = day
    let date = day.date ?? .now

    if let monthTitle {
      return monthTitle(date)
    }

    let calendar = day.calendar ?? fallbackCalendar
    let style = Date.FormatStyle(
      locale: calendar.locale ?? .autoupdatingCurrent,
      calendar: calendar,
      timeZone: calendar.timeZone
    )
    .month(.wide)
    .year()

    return date.formatted(style).localizedCapitalized
  }

  private func navigateMonth(to direction: NavigationDirection) {
    Task {
      navigationDirection = direction
      // Small delay to ensure view updates navigation direction before transition
      try? await Task.sleep(for: .seconds(0.01))
      withAnimation(.snappy(duration: 0.3)) {
        switch direction {
          case .backward:
            currentDay = day.previousMonth

          case .forward:
            currentDay = day.nextMonth
        }
      }
    }
  }

  /// Replaces the default day number with a view of your own.
  ///
  /// Called once per day of the visible month. Each cell is laid out in a square that
  /// shares the grid width equally, so size your content relative to that square rather
  /// than assuming a fixed point size.
  ///
  /// - Parameter style: A closure receiving the day's components and returning its view.
  public func withCellStyle(_ style: @escaping CellStyle<some View>) -> Self {
    var copy = self
    copy.cellStyle = { dateComponents in
      AnyView(style(dateComponents))
    }
    return copy
  }

  /// Replaces the header's month and year title.
  ///
  /// By default the title is the wide month name and the year, formatted for the
  /// calendar's locale. Override it for a different format or a fixed locale:
  ///
  /// ```swift
  /// CalendarView(currentDay: $currentDay)
  ///   .withMonthTitle { $0.formatted(.dateTime.month(.abbreviated).year()) }
  /// ```
  ///
  /// - Parameter title: A closure receiving the first-of-month date currently shown.
  public func withMonthTitle(_ title: @escaping (Date) -> String) -> Self {
    var copy = self
    copy.monthTitle = title
    return copy
  }

  /// Disables the backward chevron, for example once the calendar reaches a lower bound.
  /// - Parameter disabled: Whether to disable navigation to earlier months.
  public func backwardDisabled(_ disabled: Bool = true) -> Self {
    var copy = self
    copy.backwardDisabled = disabled
    return copy
  }

  /// Disables the forward chevron, for example once the calendar reaches an upper bound.
  /// - Parameter disabled: Whether to disable navigation to later months.
  public func forwardDisabled(_ disabled: Bool = true) -> Self {
    var copy = self
    copy.forwardDisabled = disabled
    return copy
  }
}

private struct CalendarHeader: View {
  let title: String

  private var goBackwardAction: (() -> Void)?
  private var goForwardAction: (() -> Void)?
  private var backwardDisabled: Bool
  private var forwardDisabled: Bool

  @Environment(\.calendarTheme) private var theme

  init(title: String, backwardDisabled: Bool, forwardDisabled: Bool) {
    self.title = title
    self.backwardDisabled = backwardDisabled
    self.forwardDisabled = forwardDisabled
  }

  var body: some View {
    HStack(spacing: theme.metrics.controlSpacing) {
      Text(verbatim: title)
        .font(theme.fonts.monthTitle)
        .foregroundStyle(theme.colors.monthTitle)
        .contentTransition(.numericText())

      Spacer()

      if let goBackwardAction {
        Button(action: goBackwardAction) {
          chevron("chevron.left")
        }
        .buttonStyle(.calendarNavigation)
        .disabled(backwardDisabled)
        .accessibilityLabel(Text(.previousMonth))
      }

      if let goForwardAction {
        Button(action: goForwardAction) {
          chevron("chevron.right")
        }
        .buttonStyle(.calendarNavigation)
        .disabled(forwardDisabled)
        .accessibilityLabel(Text(.nextMonth))
      }
    }
  }

  private func chevron(_ systemName: String) -> some View {
    Image(systemName: systemName)
      .font(.system(size: theme.metrics.controlSize, weight: .semibold))
  }

  func onGoBackward(perform action: @escaping () -> Void) -> Self {
    var copy = self
    copy.goBackwardAction = action
    return copy
  }

  func onGoForward(perform action: @escaping () -> Void) -> Self {
    var copy = self
    copy.goForwardAction = action
    return copy
  }
}

private struct CalendarWeekdays: View {
  let calendar: Calendar

  @Environment(\.calendarTheme) private var theme

  var body: some View {
    Grid(horizontalSpacing: 0) {
      GridRow {
        ForEach(calendar.localizedShortWeekdaySymbols, id: \.self) { day in
          Text(verbatim: day.localizedUppercase)
            .font(theme.fonts.weekdaySymbol)
            .foregroundStyle(theme.colors.weekdaySymbol)
            .frame(maxWidth: .infinity)
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

private struct CalendarNavigationButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.calendarTheme) private var theme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(isEnabled ? theme.colors.control : theme.colors.controlDisabled)
  }
}

private extension ButtonStyle where Self == CalendarNavigationButtonStyle {
  static var calendarNavigation: CalendarNavigationButtonStyle {
    CalendarNavigationButtonStyle()
  }
}

#Preview("Default theme") {
  @Previewable @State var currentDay = Calendar.autoupdatingCurrent.today

  ScrollView {
    CalendarView(currentDay: $currentDay)
      .padding()
  }
}

#Preview("Dark theme, custom cells") {
  @Previewable @State var currentDay = Calendar.autoupdatingCurrent.today

  ScrollView {
    CalendarView(currentDay: $currentDay)
      .withCellStyle { day in
        Text(verbatim: day.day?.formatted(.number) ?? "")
          .font(.system(size: 20, weight: .medium))
          .foregroundStyle(day.isWeekend ? .white.opacity(0.4) : .white)
      }
      .padding()
  }
  .background(Color.black)
  .calendarTheme(.dark)
}

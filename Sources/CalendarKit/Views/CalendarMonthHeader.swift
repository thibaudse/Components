import SwiftUI

/// A conventional month header — the title on the left, chevrons on the right — for when
/// you want the usual thing without building it.
///
/// ``CalendarView`` deliberately draws no chrome. This is the batteries-included toolbar
/// for the common case; ignore it and build your own the moment you need something else.
///
/// ```swift
/// CalendarView(currentDay: $currentDay)
///   .calendarToolbar { month in
///     CalendarMonthHeader(month)
///   }
/// ```
///
/// It styles itself from ``CalendarTheme``, and its chevrons carry localized
/// accessibility labels.
public struct CalendarMonthHeader: View {
  private let month: CalendarProxy
  private let backwardDisabled: Bool
  private let forwardDisabled: Bool

  @Environment(\.calendarTheme) private var theme

  /// Creates a month header for a calendar's proxy.
  ///
  /// - Parameters:
  ///   - month: The proxy handed to your ``CalendarView/calendarToolbar(_:content:)``
  ///     closure.
  ///   - backwardDisabled: Disables the backward chevron — pass the result of comparing
  ///     ``CalendarProxy/firstDayOfMonth`` against your own lower bound.
  ///   - forwardDisabled: Disables the forward chevron.
  public init(
    _ month: CalendarProxy,
    backwardDisabled: Bool = false,
    forwardDisabled: Bool = false
  ) {
    self.month = month
    self.backwardDisabled = backwardDisabled
    self.forwardDisabled = forwardDisabled
  }

  public var body: some View {
    HStack(spacing: theme.metrics.controlSpacing) {
      Text(verbatim: month.monthTitle)
        .font(theme.fonts.monthTitle)
        .foregroundStyle(theme.colors.monthTitle)
        .contentTransition(.numericText())

      Spacer()

      Button(action: month.goToPreviousMonth) {
        chevron("chevron.left")
      }
      .buttonStyle(.calendarNavigation)
      .disabled(backwardDisabled)
      .accessibilityLabel(Text(.previousMonth))

      Button(action: month.goToNextMonth) {
        chevron("chevron.right")
      }
      .buttonStyle(.calendarNavigation)
      .disabled(forwardDisabled)
      .accessibilityLabel(Text(.nextMonth))
    }
  }

  private func chevron(_ systemName: String) -> some View {
    Image(systemName: systemName)
      .font(.system(size: theme.metrics.controlSize, weight: .semibold))
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

#Preview {
  @Previewable @State var currentDay = Calendar.autoupdatingCurrent.today

  CalendarView(currentDay: $currentDay)
    .calendarToolbar { month in
      CalendarMonthHeader(month)
    }
    .padding()
}

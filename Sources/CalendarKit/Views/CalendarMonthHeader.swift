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
/// Like the calendar itself it carries no colors of its own, so it inherits yours. Its
/// chevrons are `Button`s with localized accessibility labels, which means
/// `buttonStyle(_:)`, `tint(_:)`, and `font(_:)` all reach them.
public struct CalendarMonthHeader: View {
  private let month: CalendarProxy
  private let backwardDisabled: Bool
  private let forwardDisabled: Bool

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
    HStack(spacing: 16) {
      Text(verbatim: month.monthTitle)
        .fontWeight(.semibold)
        .contentTransition(.numericText())
        // Scoped to the title, on the calendar's own curve: the digits morph without the
        // rest of the header — or the caller's view — being dragged into the animation.
        .animation(month.animation, value: month.monthTitle)

      Spacer()

      Button(action: month.goToPreviousMonth) {
        Image(systemName: "chevron.left")
      }
      .disabled(backwardDisabled)
      .accessibilityLabel(Text(.previousMonth))

      Button(action: month.goToNextMonth) {
        Image(systemName: "chevron.right")
      }
      .disabled(forwardDisabled)
      .accessibilityLabel(Text(.nextMonth))
    }
    .buttonStyle(.plain)
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

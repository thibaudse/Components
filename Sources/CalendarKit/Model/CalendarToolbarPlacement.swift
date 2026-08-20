import Foundation

/// Where a toolbar sits relative to the grid.
///
/// Toolbars are additive: apply ``CalendarView/calendarToolbar(_:content:)`` more than
/// once and each row is kept, stacked in the order the modifiers were applied.
public enum CalendarToolbarPlacement: Hashable, Sendable {
  /// Above the weekday symbols — the usual home for a month title and its controls.
  case above

  /// Below the grid — for a legend, a "Today" button, or a summary of the month.
  case below
}

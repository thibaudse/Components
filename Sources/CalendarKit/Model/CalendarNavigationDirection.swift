import Foundation

/// The direction a calendar is moving through time.
///
/// Handed to the closure of ``CalendarView/calendarTransition(_:)`` so a custom
/// transition can slide, wipe, or flip the right way round.
public enum CalendarNavigationDirection: Hashable, Sendable {
  /// The calendar is moving to an earlier month.
  case backward

  /// The calendar is moving to a later month.
  case forward

  /// The direction of travel between two days.
  ///
  /// Any move that is not backward counts as forward, including a move to the same day,
  /// so a calendar never lacks a direction to animate with.
  init(from current: DateComponents, to target: DateComponents) {
    self = target < current ? .backward : .forward
  }
}

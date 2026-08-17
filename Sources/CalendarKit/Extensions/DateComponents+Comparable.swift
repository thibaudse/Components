import Foundation

/// Orders `DateComponents` chronologically, so calendar code can write `day < today`
/// or sort an array of selected days.
///
/// - Important: This is a retroactive conformance to a Foundation type. If another
///   module you link also conforms `DateComponents` to `Comparable`, the duplicate
///   conformance is a build error — remove one of the two. CalendarKit's own views do
///   not rely on it, so dropping yours is always safe.
///
/// Two caveats follow from `DateComponents` being a bag of optional fields:
///
/// - Components that cannot form a date (no attached calendar, or an impossible
///   combination such as February 31st) compare as neither less nor greater than
///   anything else.
/// - Equality remains Foundation's field-by-field `==`, so components describing the
///   same instant with different fields populated are unequal *and* unordered. Compare
///   values produced the same way — ``Foundation/Calendar/calendarDateComponents(from:)``
///   makes that easy.
extension DateComponents: @retroactive Comparable {
  public static func < (lhs: DateComponents, rhs: DateComponents) -> Bool {
    guard let lhsDate = lhs.date, let rhsDate = rhs.date else {
      return false
    }
    return lhsDate < rhsDate
  }
}

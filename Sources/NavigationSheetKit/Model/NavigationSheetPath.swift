import Foundation

/// The navigation stack behind a navigation sheet.
///
/// A path is a list of `Hashable & Sendable` values, exactly like `NavigationPath`: append
/// a value to push the destination registered for its type, remove one to pop. What it adds
/// is a stable identity per entry, so the sheet can keep every screen's `@State` alive while
/// that screen sits behind the current one.
///
/// ```swift
/// @State private var path = NavigationSheetPath()
///
/// path.append(Destination.details)   // push
/// path.removeLast()                  // pop
/// path.removeAll()                   // back to the root
/// ```
///
/// Out-of-range removals are clamped rather than trapped, and reported as a fault to the
/// `NavigationSheetKit` subsystem.
public struct NavigationSheetPath: Equatable, Sendable {
  /// A path element paired with a stable identity for view preservation.
  struct IdentifiedElement: Identifiable, Sendable {
    let id: UUID
    let depth: Int
    nonisolated(unsafe) let element: AnyHashable
  }

  // Sendability is enforced at the API boundary — all mutating methods require `Hashable & Sendable`.
  private nonisolated(unsafe) var entries: [IdentifiedElement]

  /// Creates an empty path.
  public init() {
    self.entries = []
  }

  /// Creates a path from a sequence of hashable, sendable values.
  public init<S>(_ elements: S) where S: Sequence, S.Element: Hashable & Sendable {
    self.entries = elements.enumerated().map { index, element in
      IdentifiedElement(id: UUID(), depth: index + 1, element: AnyHashable(element))
    }
  }

  /// The number of elements in the path.
  public var count: Int { entries.count }

  /// A Boolean value indicating whether the path is empty.
  public var isEmpty: Bool { entries.isEmpty }

  /// Appends a new value to the end of the path.
  public mutating func append(_ value: some Hashable & Sendable) {
    entries.append(IdentifiedElement(id: UUID(), depth: entries.count + 1, element: AnyHashable(value)))
  }

  /// Removes the last `k` values from the path, clamped to the current count.
  public mutating func removeLast(_ k: Int = 1) {
    guard k >= 0 else {
      NavigationSheetLog.fault("Negative count \(k) passed to removeLast(_:)")
      return
    }
    if k > entries.count {
      NavigationSheetLog.fault("Attempted to remove \(k) elements from a path holding only \(entries.count)")
    }
    entries.removeLast(min(k, entries.count))
  }

  /// Removes all values from the path.
  public mutating func removeAll() {
    entries.removeAll()
  }

  /// The last element in the path, if any.
  public var last: AnyHashable? { entries.last?.element }

  /// All elements with stable identity for rendering.
  var identifiedElements: [IdentifiedElement] { entries }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.entries.map(\.element) == rhs.entries.map(\.element)
  }
}

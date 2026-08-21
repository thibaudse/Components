#if os(iOS)
import Observation
import SwiftUI

/// Maps path value types to the views that render them.
///
/// A path holds `AnyHashable` values; something has to turn one back into a view. Each
/// `.navigationSheetDestination(for:destination:)` registers a builder here under its value
/// type, and the sheet looks the builder up by the dynamic type of whatever it is asked to
/// push. One registry is created per presentation and shared through the environment, so
/// destinations can be declared on the root content rather than at the presenting call site.
@MainActor
@Observable
final class NavigationSheetDestinationRegistry {
  struct Entry {
    let build: (AnyHashable) -> AnyView
  }

  private var entries: [ObjectIdentifier: Entry] = [:]

  /// Registers or replaces the destination builder for a path value type.
  func register<Value: Hashable & Sendable>(
    _ type: Value.Type,
    builder: @escaping (Value) -> some View
  ) {
    entries[ObjectIdentifier(type)] = Entry(build: { value in
      guard let casted = value.base as? Value else {
        return AnyView(EmptyView())
      }
      return AnyView(builder(casted))
    })
  }

  /// The destination for a path value, or `nil` if its type was never registered.
  func destination(for value: AnyHashable) -> AnyView? {
    entries[ObjectIdentifier(type(of: value.base))]?.build(value)
  }

  /// Whether a destination builder is registered for this value's type.
  func hasDestination(for value: some Hashable & Sendable) -> Bool {
    entries[ObjectIdentifier(type(of: value))] != nil
  }
}
#endif

#if os(iOS)
import SwiftUI

/// A button that pushes a value onto the enclosing sheet's path.
///
/// The in-sheet counterpart to `NavigationLink(value:label:)`. The value's type decides which
/// destination appears, so it must have been registered with
/// `.navigationSheetDestination(for:destination:)` somewhere above.
///
/// ```swift
/// NavigationSheetLink(Destination.details) {
///   Label("Details", systemImage: "info.circle")
/// }
/// ```
///
/// A value with no registered destination does nothing and reports a fault, rather than
/// pushing a screen that would render empty.
public struct NavigationSheetLink<Value: Hashable & Sendable, Label: View>: View {
  @Environment(\.navigationSheetPath) private var navigationSheetPath
  @Environment(\.navigationSheetRegistry) private var registry

  private let role: ButtonRole?
  private let value: Value
  private let label: () -> Label

  /// Creates a link that pushes the given value.
  public init(role: ButtonRole? = nil, _ value: Value, @ViewBuilder label: @escaping () -> Label) {
    self.role = role
    self.value = value
    self.label = label
  }

  public var body: some View {
    Button(role: role) {
      guard let registry, registry.hasDestination(for: value) else {
        NavigationSheetLog.fault("No destination registered for path value: \(String(describing: value))")
        return
      }
      navigationSheetPath.wrappedValue.append(value)
    } label: {
      label()
    }
  }
}
#endif

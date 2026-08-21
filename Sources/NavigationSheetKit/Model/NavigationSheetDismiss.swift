#if os(iOS)
import SwiftUI

/// Which level of a navigation sheet to dismiss.
public enum NavigationSheetDismissBehavior: Sendable {
  /// Pops the current screen. If already at the root, dismisses the sheet.
  case current
  /// Dismisses the entire sheet regardless of navigation depth.
  case all
}

/// An action that dismisses a navigation sheet or pops its current screen.
///
/// This is the in-sheet counterpart to SwiftUI's `\.dismiss`. Retrieve it from the
/// environment and call it directly:
///
/// ```swift
/// @Environment(\.navigationSheetDismiss) private var dismiss
///
/// Button("Done") { dismiss() }       // pops current, or dismisses at root
/// Button("Close") { dismiss(.all) }  // always dismisses the sheet
/// ```
///
/// Called outside a navigation sheet it does nothing and reports a fault.
public struct NavigationSheetDismissAction {
  private let handler: @MainActor (NavigationSheetDismissBehavior) -> Void

  init(handler: @escaping @MainActor (NavigationSheetDismissBehavior) -> Void = { _ in
    NavigationSheetLog.fault("navigationSheetDismiss called outside of a navigation sheet")
  }) {
    self.handler = handler
  }

  /// Dismisses the navigation sheet with the given behavior.
  @MainActor
  public func callAsFunction(_ behavior: NavigationSheetDismissBehavior = .current) {
    handler(behavior)
  }
}
#endif

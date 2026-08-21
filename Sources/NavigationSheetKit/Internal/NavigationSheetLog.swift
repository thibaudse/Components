import os

/// The faults NavigationSheetKit reports when its API is used in a way it cannot honour.
///
/// Every case here is a programmer error the component recovers from — a path value with
/// no registered destination, a pop past the root, a dismiss action retrieved outside a
/// sheet. They are logged rather than trapped on purpose: a library has no business
/// terminating its host's debug build over something it can clamp or skip. Look for them
/// in Console.app under the `NavigationSheetKit` subsystem.
enum NavigationSheetLog {
  private static let logger = Logger(subsystem: "NavigationSheetKit", category: "NavigationSheet")

  static func fault(_ message: String) {
    logger.fault("\(message, privacy: .public)")
  }
}

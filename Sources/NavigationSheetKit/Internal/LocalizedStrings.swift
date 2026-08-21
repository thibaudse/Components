import Foundation

/// The strings NavigationSheetKit displays itself.
///
/// Two accessibility labels, for the two shapes the built-in navigation button takes. They
/// resolve against the package's own string catalog via `Bundle.module`, so they translate
/// independently of the host app — an app localized only in English still gets a French
/// "Retour" on a French device.
///
/// The property names deliberately differ from the keys: Xcode generates its own accessors
/// from a string catalog, named after the key, and a property matching one would collide with
/// it in Xcode builds while being absent from `swift build`.
extension LocalizedStringResource {
  static var navigationBack: LocalizedStringResource {
    LocalizedStringResource(
      "navigationSheet.button.back",
      defaultValue: "Back",
      table: "Localizable",
      bundle: .atURL(Bundle.module.bundleURL),
      comment: "Accessibility label for the button that returns to the previous screen in a navigation sheet."
    )
  }

  static var navigationClose: LocalizedStringResource {
    LocalizedStringResource(
      "navigationSheet.button.close",
      defaultValue: "Close",
      table: "Localizable",
      bundle: .atURL(Bundle.module.bundleURL),
      comment: "Accessibility label for the button that dismisses a navigation sheet."
    )
  }
}

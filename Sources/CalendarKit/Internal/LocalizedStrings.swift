import Foundation

/// The strings CalendarKit displays itself.
///
/// Everything else a calendar shows — month names, weekday symbols, day numbers — is
/// derived from the calendar and its locale, so these two accessibility labels are the
/// only literals in the package. They resolve against the package's own string catalog
/// via `Bundle.module`, which keeps them independent of the app's localizations.
extension LocalizedStringResource {
  static var previousMonth: LocalizedStringResource {
    LocalizedStringResource(
      "calendar.header.previousMonth",
      defaultValue: "Previous month",
      table: "Localizable",
      bundle: .atURL(Bundle.module.bundleURL),
      comment: "Accessibility label for the button that moves the calendar to the preceding month."
    )
  }

  static var nextMonth: LocalizedStringResource {
    LocalizedStringResource(
      "calendar.header.nextMonth",
      defaultValue: "Next month",
      table: "Localizable",
      bundle: .atURL(Bundle.module.bundleURL),
      comment: "Accessibility label for the button that moves the calendar to the following month."
    )
  }
}

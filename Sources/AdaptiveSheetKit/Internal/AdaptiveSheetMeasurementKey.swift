#if os(iOS)
import SwiftUI

/// Carries the sheet content's latest reading up to whatever sizes the sheet.
///
/// `nil` until the content has reported once. Only one view measures, so the last non-nil reading
/// is the reading.
struct AdaptiveSheetMeasurementKey: PreferenceKey {
  static let defaultValue: AdaptiveSheetReading? = nil

  static func reduce(value: inout AdaptiveSheetReading?, nextValue: () -> AdaptiveSheetReading?) {
    value = nextValue() ?? value
  }
}
#endif

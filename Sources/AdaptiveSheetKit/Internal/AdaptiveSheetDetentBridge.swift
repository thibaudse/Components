#if os(iOS)
import SwiftUI

/// Hands an adaptive sheet's measurement to the UIKit sheet SwiftUI presented it in.
///
/// SwiftUI only interpolates between detents a sheet has already been offered, so a `.height` that
/// follows the content jumps rather than resizes. The sheet's own `UISheetPresentationController` is
/// sized directly instead — see
/// ``AdaptiveSheetDetentController``. Everything else about the presentation stays SwiftUI's, which is
/// why the `.presentation*` modifiers keep working on an adaptive sheet.
struct AdaptiveSheetDetentBridge: UIViewControllerRepresentable {
  /// The content's latest reading, or `nil` until it has reported.
  let reading: AdaptiveSheetReading?

  func makeUIViewController(context: Context) -> AdaptiveSheetDetentController {
    AdaptiveSheetDetentController()
  }

  func updateUIViewController(_ controller: AdaptiveSheetDetentController, context: Context) {
    controller.apply(reading)
  }
}
#endif

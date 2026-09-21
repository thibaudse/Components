#if os(iOS)
import SwiftUI
import UIKit

/// One screen of the sheet: a hosting controller around the caller's SwiftUI content.
///
/// The host wraps the content with everything a screen needs — the caller's environment, the
/// sheet's environment keys, and the measurement modifier — and observes the screen's
/// preferences at its own root, forwarding them to the UIKit side through callbacks.
/// Preferences work here because they never have to cross a hosting boundary: each screen owns
/// its whole SwiftUI tree.
final class NavigationSheetScreenController: UIHostingController<NavigationSheetScreenHost> {
  /// The screen's depth in the path — `0` for the root.
  let depth: Int
  /// The screen's latest measured height, or `nil` before it has reported.
  private(set) var measuredHeight: CGFloat?
  /// The detent this screen asked for explicitly, if any.
  private(set) var preferredDetent: NavigationSheetPreferredDetent = .automatic
  /// Called whenever the measured height or preferred detent changes.
  var onSizingChange: () -> Void = {}

  init(depth: Int, model: NavigationSheetModel, content: AnyView) {
    self.depth = depth
    super.init(rootView: NavigationSheetScreenHost(depth: depth, model: model, content: content))
    rootView.onMeasurement = { [weak self] measurement in
      guard let self, measurement.detentHeight > 0 else { return }
      guard measuredHeight != measurement.detentHeight else { return }
      measuredHeight = measurement.detentHeight
      onSizingChange()
    }
    rootView.onPreferredDetent = { [weak self] detent in
      guard let self, preferredDetent != detent else { return }
      preferredDetent = detent
      onSizingChange()
    }
    rootView.onToolbarHiddenChange = { [weak self] hidden in
      self?.setToolbarHidden(hidden)
    }
    view.backgroundColor = .clear
    // The bar floats over the content; this is what makes scroll views start below it and
    // scroll under it, the way content behaves under a navigation bar.
    additionalSafeAreaInsets.top = NavigationSheetMetrics.barHeight

    // Hosting controllers propose the safe area to their content by default; the sheet's
    // measurement needs the content's answer, not the proposal's echo.
    sizingOptions = []
  }

  @available(*, unavailable)
  @MainActor required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  /// The height the sheet should be for this screen, if it is known.
  ///
  /// An explicit detent wins over the measurement, mirroring the SwiftUI port's priority.
  var requestedDetentHeight: NavigationSheetDetentRequest {
    switch preferredDetent {
      case .detent(let value):
        return .explicit(value)

      case .automatic:
        if let measuredHeight {
          return .height(measuredHeight)
        }
        return .unknown
    }
  }

  /// Collapses or restores the bar inset when the bar hides for this screen.
  func setToolbarHidden(_ hidden: Bool) {
    let inset = hidden ? NavigationSheetMetrics.collapsedBarHeight : NavigationSheetMetrics.barHeight
    guard additionalSafeAreaInsets.top != inset else { return }
    additionalSafeAreaInsets.top = inset
  }
}

/// What one screen asks of the sheet's height.
enum NavigationSheetDetentRequest {
  /// The screen forced a specific detent.
  case explicit(PresentationDetent)
  /// The screen measured this tall.
  case height(CGFloat)
  /// The screen has not reported yet.
  case unknown
}

/// The SwiftUI tree hosted for one screen.
struct NavigationSheetScreenHost: View {
  let depth: Int
  let model: NavigationSheetModel
  let content: AnyView

  /// Forwarders into the screen controller. Mutable so the controller can attach them after
  /// `super.init`, since they capture `self`.
  var onMeasurement: (NavigationSheetContentMeasurement) -> Void = { _ in }
  var onPreferredDetent: (NavigationSheetPreferredDetent) -> Void = { _ in }
  var onToolbarHiddenChange: (Bool) -> Void = { _ in }

  var body: some View {
    content
      .safeAreaPadding(.bottom, bottomSafeAreaPadding)
      .modifier(NavigationSheetContentMeasurementModifier(pathDepth: depth))
      // Top-aligned in the hosting view, applied outside the measurement so the measurement
      // still sees the content's natural size. A hosting view centres by default, which
      // would float short content mid-sheet at the large detent.
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .onPreferenceChange(NavigationSheetContentMeasurementKey.self) { measurements in
        // One screen per host, so the first (and only) entry is ours.
        if let measurement = measurements.first {
          MainActor.assumeIsolated {
            onMeasurement(measurement)
          }
        }
      }
      .onPreferenceChange(NavigationSheetDetentKey.self) { items in
        MainActor.assumeIsolated {
          onPreferredDetent(items.first?.detent ?? .automatic)
        }
      }
      .onPreferenceChange(NavigationSheetToolbarItemsKey.self) { items in
        MainActor.assumeIsolated {
          model.toolbarItemsByDepth[depth] = items
        }
      }
      .onPreferenceChange(NavigationSheetToolbarHiddenKey.self) { depths in
        MainActor.assumeIsolated {
          let isHidden = !depths.isEmpty
          if isHidden {
            model.toolbarHiddenDepths.insert(depth)
          } else {
            model.toolbarHiddenDepths.remove(depth)
          }
          // The bar's own content reads `model.isToolbarHidden` and collapses on its own, but
          // the inset the screen sits under is UIKit's and has to be told. Forwarded from here
          // rather than read once when the screen is installed: a preference cannot report
          // before the layout pass that installs the screen, so the install-time read always
          // sees a screen that has not spoken yet.
          onToolbarHiddenChange(isHidden)
        }
      }
      .onPreferenceChange(NavigationSheetNavigationButtonKey.self) { items in
        MainActor.assumeIsolated {
          model.navigationButtonsByDepth[depth] = items.first?.override
        }
      }
      .onPreferenceChange(NavigationSheetBackgroundKey.self) { items in
        MainActor.assumeIsolated {
          model.screenBackgroundsByDepth[depth] = items.first?.content
        }
      }
      .onPreferenceChange(NavigationSheetBackgroundOverlayKey.self) { items in
        MainActor.assumeIsolated {
          model.backgroundOverlaysByDepth[depth] = items.first?.content
        }
      }
      .environment(\.navigationSheetPathDepth, depth)
      .environment(\.navigationSheetDismiss, model.dismissAction)
      .environment(\.navigationSheetIsLargeDetent, model.isLargeDetent)
      .environment(\.navigationSheetContainerInsets, model.containerInsets)
      .environment(\.navigationSheetRegistry, model.registry)
      .environment(\.navigationSheetPath, model.pathBinding)
      // Outermost, so the caller's environment is the base the keys above override —
      // the other way round, replacing `\.self` would wipe them.
      .environment(\.self, model.environment)
  }

  /// Bottom margin for devices with a physical home button, which have no home indicator
  /// to provide one. The container's own bottom inset is the known answer: zero exactly
  /// when there is no home indicator.
  private var bottomSafeAreaPadding: CGFloat {
    model.containerInsets.bottom == 0 ? NavigationSheetMetrics.homeButtonBottomPadding : 0
  }
}
#endif

#if os(iOS)
import SwiftUI
import UIKit

/// The bridge from the SwiftUI modifiers to the UIKit sheet.
///
/// A zero-size anchor view controller sits in the presenting hierarchy; its coordinator
/// presents and dismisses ``NavigationSheetController`` as the binding flips, forwards every
/// path change into the controller, and forwards every controller-initiated change — back,
/// edge swipe, swipe-down — back into the bindings. The bindings stay the source of truth;
/// the controller is their view.
struct NavigationSheetPresenter: UIViewControllerRepresentable {
  let isPresented: Bool
  @Binding var path: NavigationSheetPath
  let destinationRegistry: NavigationSheetDestinationRegistry
  let root: () -> AnyView
  /// Sets the presenting binding false — `isPresented = false` or `item = nil`.
  let setDismissed: () -> Void

  func makeUIViewController(context: Context) -> NavigationSheetAnchorController {
    NavigationSheetAnchorController()
  }

  func updateUIViewController(_ anchor: NavigationSheetAnchorController, context: Context) {
    let coordinator = context.coordinator
    coordinator.parent = self
    coordinator.environment = context.environment

    if isPresented {
      if let controller = coordinator.controller {
        // Already up: sync the path and the environment.
        controller.model.environment = context.environment
        controller.setPath(path)
      } else {
        coordinator.present(from: anchor)
      }
    } else {
      coordinator.dismiss()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  @MainActor
  final class Coordinator: NSObject, UISheetPresentationControllerDelegate {
    var parent: NavigationSheetPresenter
    var environment = EnvironmentValues()
    var controller: NavigationSheetController?

    init(parent: NavigationSheetPresenter) {
      self.parent = parent
      super.init()
    }

    func present(from anchor: NavigationSheetAnchorController) {
      // The anchor must be in a window before it can present, and SwiftUI's first update
      // often arrives before that — a sheet whose binding starts true, for one. The anchor
      // calls back the moment it lands in a window.
      guard anchor.viewIfLoaded?.window != nil else {
        anchor.onWindowAvailable = { [weak self, weak anchor] in
          guard let self, let anchor, parent.isPresented, self.controller == nil else { return }
          present(from: anchor)
        }
        return
      }
      anchor.onWindowAvailable = nil
      guard anchor.presentedViewController == nil else { return }

      let model = NavigationSheetModel()
      model.environment = environment
      model.chrome = environment.navigationSheetChrome
      model.registry = parent.destinationRegistry
      model.pathBinding = parent.$path
      model.dismissSheet = { [weak self] in
        self?.dismissFromInside()
      }

      let controller = NavigationSheetController(
        model: model,
        destinationRegistry: parent.destinationRegistry,
        root: parent.root
      )
      controller.onPathPop = { [weak self] depth in
        guard let self else { return }
        let excess = parent.path.count - depth
        if excess > 0 {
          parent.path.removeLast(excess)
        }
      }
      controller.modalPresentationStyle = .pageSheet
      controller.configureSheet()
      controller.sheetPresentationController?.delegate = self
      controller.presentationController?.delegate = self

      self.controller = controller
      anchor.present(controller, animated: true)

      // The path can already hold values when the sheet opens (deep links).
      if !parent.path.isEmpty {
        controller.setPath(parent.path)
      }
    }

    func dismiss() {
      guard let controller, controller.presentingViewController != nil else {
        self.controller = nil
        return
      }
      self.controller = nil
      controller.dismiss(animated: true)
      // This runs during a SwiftUI update pass (the binding just flipped); mutating the
      // path binding here too would be a state change mid-update. Next turn of the loop.
      Task { @MainActor [self] in
        parent.path.removeAll()
      }
    }

    /// The sheet asked to go — dismiss action, close button.
    private func dismissFromInside() {
      // Flip the binding and let the update pass call `dismiss()`, so the binding stays
      // the one source of truth for whether the sheet is up.
      parent.setDismissed()
    }

    // MARK: - UISheetPresentationControllerDelegate

    /// The user swiped the sheet down. UIKit already dismissed it; sync the bindings.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
      controller = nil
      parent.path.removeAll()
      parent.setDismissed()
    }
  }
}

/// The invisible view controller the sheet is presented from.
final class NavigationSheetAnchorController: UIViewController {
  /// Fires once the anchor can actually present — set by the coordinator when a present
  /// request arrived before the anchor was in a window.
  var onWindowAvailable: (() -> Void)?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if view.window != nil, let onWindowAvailable {
      self.onWindowAvailable = nil
      onWindowAvailable()
    }
  }
}
#endif

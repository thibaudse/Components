#if os(iOS)
import SwiftUI
import UIKit

/// Reports the hosting window's safe area insets.
///
/// The sheet needs the *device's* insets, not its own. Its own bottom inset is whatever the
/// presentation hands it; what the layout actually depends on is whether the device has a
/// home indicator, because a device without one has to be given that bottom margin
/// explicitly.
///
/// A host app would normally read this once at its root and inject it, but a package cannot
/// ask its consumers to remember a setup call for the layout to come out right — that is a
/// silent failure on exactly one class of device. So it reads the window itself. `view.window`
/// is the app's window even from inside a sheet, which also keeps this clear of
/// `UIApplication.shared`, unavailable to app extensions.
struct WindowSafeAreaReader: UIViewRepresentable {
  let onChange: (EdgeInsets) -> Void

  func makeUIView(context: Context) -> ProbeView {
    ProbeView(onChange: onChange)
  }

  func updateUIView(_ uiView: ProbeView, context: Context) {
    uiView.onChange = onChange
  }

  final class ProbeView: UIView {
    var onChange: (EdgeInsets) -> Void

    init(onChange: @escaping (EdgeInsets) -> Void) {
      self.onChange = onChange
      super.init(frame: .zero)
      isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) is not supported")
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      report()
    }

    override func safeAreaInsetsDidChange() {
      super.safeAreaInsetsDidChange()
      report()
    }

    private func report() {
      guard let insets = window?.safeAreaInsets else { return }
      let edgeInsets = EdgeInsets(
        top: insets.top,
        leading: insets.left,
        bottom: insets.bottom,
        trailing: insets.right
      )
      // Both callers run inside a layout pass, and the handler writes to @State. Hop to the
      // next turn of the main queue so the write lands after the update, not during it.
      Task { [onChange] in
        onChange(edgeInsets)
      }
    }
  }
}
#endif

#if os(iOS)
import UIKit
import os

/// Private UIKit, called by selector name.
///
/// Every selector here was found by dumping `UISheetPresentationController` and
/// `_UISheetPresentationController` with the Objective-C runtime on iOS 27.2. Each call checks
/// `responds(to:)` first, so a selector missing on the running iOS is logged and skipped instead
/// of crashing. None of this would pass App Review.
enum PrivateSheetAPI {
  static let log = Logger(subsystem: "CardSheetKit", category: "PrivateAPI")
}

extension NSObject {
  @discardableResult
  func privateSet(_ selector: String, _ value: Bool) -> Bool {
    guard let imp = privateImplementation(selector) else { return false }
    typealias Setter = @convention(c) (NSObject, Selector, Bool) -> Void
    unsafeBitCast(imp, to: Setter.self)(self, NSSelectorFromString(selector), value)
    return true
  }

  @discardableResult
  func privateSet(_ selector: String, _ value: CGFloat) -> Bool {
    guard let imp = privateImplementation(selector) else { return false }
    typealias Setter = @convention(c) (NSObject, Selector, CGFloat) -> Void
    unsafeBitCast(imp, to: Setter.self)(self, NSSelectorFromString(selector), value)
    return true
  }

  @discardableResult
  func privateSet(_ selector: String, _ value: AnyObject?) -> Bool {
    guard let imp = privateImplementation(selector) else { return false }
    typealias Setter = @convention(c) (NSObject, Selector, AnyObject?) -> Void
    unsafeBitCast(imp, to: Setter.self)(self, NSSelectorFromString(selector), value)
    return true
  }

  func privateObject(_ selector: String) -> AnyObject? {
    let sel = NSSelectorFromString(selector)
    guard responds(to: sel) else {
      PrivateSheetAPI.log.error("\(selector, privacy: .public) is not available on this iOS")
      return nil
    }
    return perform(sel)?.takeUnretainedValue()
  }

  private func privateImplementation(_ selector: String) -> IMP? {
    let sel = NSSelectorFromString(selector)
    guard responds(to: sel) else {
      PrivateSheetAPI.log.error("\(selector, privacy: .public) is not available on this iOS")
      return nil
    }
    return method(for: sel)
  }
}

extension UISheetPresentationController {
  /// `_wantsFullScreen`: the sheet covers the whole display, status bar included. Not a detent:
  /// it pins the sheet's frame to the display whatever detent is selected. The presenter stays
  /// visible, dimmed, behind whatever the sheet's content leaves transparent.
  func setWantsFullScreen(_ value: Bool) { privateSet("_setWantsFullScreen:", value) }


  /// `_preferredShadowOpacity`: the sheet's own shadow. Zero, because each card draws itself.
  func setShadowOpacity(_ value: CGFloat) { privateSet("_setPreferredShadowOpacity:", value) }

  /// `_largeBackground`: the material the sheet paints behind its content at the large detent.
  func setLargeBackground(_ material: AnyObject?) { privateSet("_setLargeBackground:", material) }

  /// `_confinedDimmingView`: the view that actually dims the presenter under a full-screen sheet
  /// — black at 20%, inside the presenter's own drop-shadow view. (The sheet's `dimmingView` is
  /// there too but clear.) Faded by hand while a card is pulled down to be dismissed, since the
  /// dismissal is the card's own; UIKit only removes it once the sheet's dismissal completes.
  var presenterDimmingView: UIView? { privateObject("_confinedDimmingView") as? UIView }

  /// `dropShadowView`: the view that carries the sheet's background, corner mask and shadow.
  var sheetChromeView: UIView? { privateObject("dropShadowView") as? UIView }
}

extension UINavigationController {
  /// `_verticalBarEligibleEdges` → none, through a runtime subclass of this one controller's
  /// class. An iPhone Duo runs its status bar down the side, and a navigation controller whose
  /// view reaches that edge of the display is drawn as that display's full-screen one: its bar
  /// one 28 pt title with no large title, its content's top 52 pt higher, the window's side inset
  /// let in past any its parent gives. A card reaches that edge whenever it is off to the right,
  /// slides past it, or is full screen — and its title jumped as it switched. Eligible for no
  /// such edge, a card's bar is a sheet's everywhere; the engine keeps it clear of the status
  /// bar with the side safe area it gives the controller.
  func ignoreSideStatusBar() {
    let selector = NSSelectorFromString("_verticalBarEligibleEdges")
    guard let original = object_getClass(self) else { return }
    let prefix = "CardSheetKitNoSideStatusBar_"
    if NSStringFromClass(original).hasPrefix(prefix) { return }
    guard let method = class_getInstanceMethod(original, selector) else {
      PrivateSheetAPI.log.error("_verticalBarEligibleEdges is not available on this iOS")
      return
    }
    let name = prefix + NSStringFromClass(original)
    let subclass: AnyClass
    if let existing = NSClassFromString(name) {
      subclass = existing
    } else {
      guard let created = objc_allocateClassPair(original, name, 0) else { return }
      let none: @convention(block) (AnyObject) -> UInt = { _ in 0 }
      class_addMethod(created, selector, imp_implementationWithBlock(none), method_getTypeEncoding(method))
      objc_registerClassPair(created)
      subclass = created
    }
    object_setClass(self, subclass)
  }
}
#endif

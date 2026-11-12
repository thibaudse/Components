#if os(iOS)
internal import CardSheetKitObjC
import ObjectiveC
import SwiftUI
import UIKit

/// What SwiftUI's own presentation modifiers set on the sheet, read back from it and translated
/// into the card's terms: positions are card tops, in the display's coordinates.
struct SheetConfiguration: Equatable {
  /// `presentationDetents`: where the card's top is at each detent.
  var detentTops: [CGFloat] = []
  /// `presentationDetents(_:selection:)`: the detent the card should be at, if one is chosen.
  var selectedTop: CGFloat?
  /// `presentationDragIndicator`.
  var showsGrabber = false
  /// `presentationCornerRadius`; nil is automatic.
  var cornerRadius: CGFloat?
  /// `presentationBackgroundInteraction(.enabled(upThrough:))`: at or below this top, the
  /// presenter is not dimmed.
  var undimmedTop: CGFloat?
  /// `presentationContentInteraction(.scrolls)`: the content scrolls at every height, rather
  /// than the card moving first.
  var contentScrollsFirst = false
}

/// Takes over the `UISheetPresentationController` SwiftUI configured for a card sheet.
///
/// SwiftUI translates its presentation modifiers into the sheet's properties — detents, grabber,
/// corner radius, undimmed detent, scroll-to-expand. They are read once, then the sheet is given
/// a runtime subclass that records every later write instead of applying it, so SwiftUI updating
/// a modifier moves the card rather than undoing the full-screen setup. The sheet itself becomes
/// the invisible, full-screen host the cards are drawn in.
@MainActor
final class SheetTakeover {
  private weak var sheet: UISheetPresentationController?
  private let bounds: CGRect
  private let safeArea: UIEdgeInsets
  private let traits: UITraitCollection
  private let onChange: (SheetConfiguration) -> Void

  private var detents: [UISheetPresentationController.Detent]
  private var selected: UISheetPresentationController.Detent.Identifier?
  private var grabber: Bool
  private var cornerRadius: CGFloat
  private var undimmed: UISheetPresentationController.Detent.Identifier?
  private var scrollExpands: Bool

  init(
    sheet: UISheetPresentationController, bounds: CGRect, safeArea: UIEdgeInsets,
    traits: UITraitCollection, onChange: @escaping (SheetConfiguration) -> Void
  ) {
    self.sheet = sheet
    self.bounds = bounds
    self.safeArea = safeArea
    self.traits = traits
    self.onChange = onChange
    // What SwiftUI set before the content appeared.
    detents = sheet.detents
    selected = sheet.selectedDetentIdentifier
    grabber = sheet.prefersGrabberVisible
    cornerRadius = sheet.preferredCornerRadius.map { $0 } ?? -1
    undimmed = sheet.largestUndimmedDetentIdentifier
    scrollExpands = sheet.prefersScrollingExpandsWhenScrolledToEdge

    SheetRecorder.install(on: sheet, takeover: self)
    applyHostSetup(to: sheet)
    onChange(configuration)
  }

  var configuration: SheetConfiguration {
    let tops = detents.compactMap(top(of:))
    let selectedTop = selected.flatMap { id in detents.first { $0.identifier == id } }.flatMap(top(of:))
    let undimmedTop = undimmed.flatMap { id in detents.first { $0.identifier == id } }.flatMap(top(of:))
    return SheetConfiguration(
      detentTops: tops.isEmpty ? [safeArea.top] : tops,
      selectedTop: selectedTop,
      showsGrabber: grabber,
      cornerRadius: cornerRadius >= 0 && cornerRadius.isFinite ? cornerRadius : nil,
      undimmedTop: undimmedTop,
      contentScrollsFirst: !scrollExpands
    )
  }

  /// A detent's height, as UIKit itself resolves it, turned into the card's top. UIKit's
  /// resolvers expect a context with private methods too; `DetentContext` has them, and a
  /// resolver that still raises is caught rather than taking the app down.
  private func top(of detent: UISheetPresentationController.Detent) -> CGFloat? {
    let context = DetentContext(bounds: bounds, safeArea: safeArea, traits: traits)
    var value: CGFloat?
    if let exception = CardSheetKitTry({ value = detent.resolvedValue(in: context) }) {
      PrivateSheetAPI.log.error("detent \(detent.identifier.rawValue, privacy: .public) could not be resolved: \(exception.reason ?? "?", privacy: .public)")
      return nil
    }
    guard let value, value > 0 else { return nil }
    return max(bounds.height - value - safeArea.bottom, 0)
  }

  // MARK: Writes SwiftUI makes later

  fileprivate func record(detents value: [UISheetPresentationController.Detent]) { detents = value; onChange(configuration) }
  fileprivate func record(selected value: UISheetPresentationController.Detent.Identifier?) { selected = value; onChange(configuration) }
  fileprivate func record(grabber value: Bool) { grabber = value; onChange(configuration) }
  fileprivate func record(cornerRadius value: CGFloat) { cornerRadius = value; onChange(configuration) }
  fileprivate func record(undimmed value: UISheetPresentationController.Detent.Identifier?) { undimmed = value; onChange(configuration) }
  fileprivate func record(scrollExpands value: Bool) { scrollExpands = value; onChange(configuration) }

  // MARK: The sheet as an invisible full-screen host

  private func applyHostSetup(to sheet: UISheetPresentationController) {
    // Through the original setters: the recorder only intercepts SwiftUI's writes.
    SheetRecorder.bypassing {
      sheet.detents = [.large()]
      sheet.selectedDetentIdentifier = nil
      sheet.prefersGrabberVisible = false
      sheet.preferredCornerRadius = 0
      sheet.largestUndimmedDetentIdentifier = nil
      sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }
    sheet.setWantsFullScreen(true)
    // The sheet's own pull-to-dismiss would move every card at once; dismissal is the
    // current card's own drag.
    sheet.privateSet("_setAllowsInteractiveDismissWhenFullScreen:", false)
    sheet.setShadowOpacity(0)
    sheet.setLargeBackground(nil)
    clearChrome()
  }

  /// The sheet's background, shadow and rounded mask would draw — and crop — a panel around the
  /// cards; it re-applies them when it changes shape, so this runs again on layout.
  func clearChrome() {
    guard let sheet, let chrome = sheet.sheetChromeView else { return }
    let content = sheet.presentedViewController.view
    chrome.backgroundColor = .clear
    chrome.layer.shadowOpacity = 0
    var stack: [UIView] = [chrome]
    while let current = stack.popLast() {
      if let content, current.isDescendant(of: content), current !== content { continue }
      current.layer.cornerRadius = 0
      current.layer.mask = nil
      current.clipsToBounds = false
      current.backgroundColor = .clear
      stack.append(contentsOf: current.subviews)
    }
  }
}

/// A detent resolution context with the private methods UIKit's own resolvers call on it — the
/// medium detent asks for `_containerBounds`, for one. Found by implementing the private
/// protocol's members and logging which are asked for.
final class DetentContext: NSObject, UISheetPresentationControllerDetentResolutionContext {
  let containerTraitCollection: UITraitCollection
  let maximumDetentValue: CGFloat
  private let bounds: CGRect
  private let safeArea: UIEdgeInsets

  init(bounds: CGRect, safeArea: UIEdgeInsets, traits: UITraitCollection) {
    self.bounds = bounds
    self.safeArea = safeArea
    containerTraitCollection = traits
    // A large sheet fills the display between the status bar and the home indicator.
    maximumDetentValue = bounds.height - safeArea.top - safeArea.bottom
  }

  @objc var _isInverted: Bool { false }
  @objc var _isEdgeAttached: Bool { true }
  @objc var _containerBounds: CGRect { bounds }
  @objc var _containerSafeAreaInsets: UIEdgeInsets { safeArea }
  @objc var _containerTraitCollection: UITraitCollection { containerTraitCollection }
  @objc var _effectiveKeyboardFrame: CGRect { .zero }
  @objc var _fullHeightPresentedViewFrame: CGRect {
    CGRect(x: 0, y: safeArea.top, width: bounds.width, height: bounds.height - safeArea.top)
  }
  @objc var _maximumDetentValue: CGFloat { maximumDetentValue }
  @objc var _fullDetentValue: CGFloat { maximumDetentValue }
  @objc var _minimumSize: CGSize { .zero }
  @objc var _grabberSpacing: CGFloat { 0 }
  @objc var _grabberSize: CGSize { .zero }
  @objc var _containerView: UIView? { nil }
  @objc var _detentProvider: AnyObject? { nil }
}

/// Gives one sheet instance a runtime subclass of its own class whose setters report to the
/// takeover and apply nothing — so SwiftUI changing `presentationDetents` (or any of the
/// others) later is seen, and cannot put the sheet back to the size it asked for.
@MainActor
private enum SheetRecorder {
  private static var takeoverKey: UInt8 = 0
  private static var isBypassing = false

  static func bypassing(_ changes: () -> Void) {
    isBypassing = true
    changes()
    isBypassing = false
  }

  static func install(on sheet: UISheetPresentationController, takeover: SheetTakeover) {
    objc_setAssociatedObject(sheet, &takeoverKey, takeover, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    guard let original = object_getClass(sheet) else { return }
    let name = "CardSheetKitRecording_" + NSStringFromClass(original)
    if NSStringFromClass(original).hasPrefix("CardSheetKitRecording_") { return }
    let subclass: AnyClass
    if let existing = NSClassFromString(name) {
      subclass = existing
    } else {
      guard let created = objc_allocateClassPair(original, name, 0) else { return }
      addOverrides(to: created, original: original)
      objc_registerClassPair(created)
      subclass = created
    }
    object_setClass(sheet, subclass)
  }

  private static func takeover(of sheet: AnyObject) -> SheetTakeover? {
    objc_getAssociatedObject(sheet, &takeoverKey) as? SheetTakeover
  }

  private static func addOverrides(to subclass: AnyClass, original: AnyClass) {
    override(subclass, original, "setDetents:") { (sheet: AnyObject, value: AnyObject?) in
      takeover(of: sheet)?.record(detents: (value as? [UISheetPresentationController.Detent]) ?? [])
    }
    override(subclass, original, "setSelectedDetentIdentifier:") { (sheet: AnyObject, value: AnyObject?) in
      takeover(of: sheet)?.record(selected: (value as? String).map { .init($0) })
    }
    override(subclass, original, "setLargestUndimmedDetentIdentifier:") { (sheet: AnyObject, value: AnyObject?) in
      takeover(of: sheet)?.record(undimmed: (value as? String).map { .init($0) })
    }
    overrideBool(subclass, original, "setPrefersGrabberVisible:") { sheet, value in
      takeover(of: sheet)?.record(grabber: value)
    }
    overrideBool(subclass, original, "setPrefersScrollingExpandsWhenScrolledToEdge:") { sheet, value in
      takeover(of: sheet)?.record(scrollExpands: value)
    }
    overrideFloat(subclass, original, "setPreferredCornerRadius:") { sheet, value in
      takeover(of: sheet)?.record(cornerRadius: value)
    }
  }

  private typealias ObjectSetter = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
  private typealias BoolSetter = @convention(c) (AnyObject, Selector, Bool) -> Void
  private typealias FloatSetter = @convention(c) (AnyObject, Selector, CGFloat) -> Void

  private static func override(
    _ subclass: AnyClass, _ original: AnyClass, _ name: String,
    _ record: @escaping @MainActor (AnyObject, AnyObject?) -> Void
  ) {
    let selector = NSSelectorFromString(name)
    guard let method = class_getInstanceMethod(original, selector) else { return }
    let superIMP = unsafeBitCast(method_getImplementation(method), to: ObjectSetter.self)
    let block: @convention(block) (AnyObject, AnyObject?) -> Void = { sheet, value in
      MainActor.assumeIsolated {
        if isBypassing || takeover(of: sheet) == nil { superIMP(sheet, selector, value) } else { record(sheet, value) }
      }
    }
    class_addMethod(subclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
  }

  private static func overrideBool(
    _ subclass: AnyClass, _ original: AnyClass, _ name: String,
    _ record: @escaping @MainActor (AnyObject, Bool) -> Void
  ) {
    let selector = NSSelectorFromString(name)
    guard let method = class_getInstanceMethod(original, selector) else { return }
    let superIMP = unsafeBitCast(method_getImplementation(method), to: BoolSetter.self)
    let block: @convention(block) (AnyObject, Bool) -> Void = { sheet, value in
      MainActor.assumeIsolated {
        if isBypassing || takeover(of: sheet) == nil { superIMP(sheet, selector, value) } else { record(sheet, value) }
      }
    }
    class_addMethod(subclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
  }

  private static func overrideFloat(
    _ subclass: AnyClass, _ original: AnyClass, _ name: String,
    _ record: @escaping @MainActor (AnyObject, CGFloat) -> Void
  ) {
    let selector = NSSelectorFromString(name)
    guard let method = class_getInstanceMethod(original, selector) else { return }
    let superIMP = unsafeBitCast(method_getImplementation(method), to: FloatSetter.self)
    let block: @convention(block) (AnyObject, CGFloat) -> Void = { sheet, value in
      MainActor.assumeIsolated {
        if isBypassing || takeover(of: sheet) == nil { superIMP(sheet, selector, value) } else { record(sheet, value) }
      }
    }
    class_addMethod(subclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
  }
}
#endif

import AppKit
import MultishellAppCore
import MultishellCore

/// The keyboard a reconcile, a closed find bar or a cancelled composer handed a file or
/// All changes tab, taken by its text view or list, or the view behind an image or notice.
extension NSView {
  func takeKeyboard(ifAskedBy model: AppModel, for tabID: FileTab.ID) {
    guard model.takeFileTabFocusRequest(tabID) else { return }
    // A turn later, once the view is in its window.
    Task { @MainActor in takeFirstResponder() }
  }
}

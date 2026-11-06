import AppKit
import MultishellAppCore
import MultishellCore

/// The keyboard a reconcile or a closed find bar handed a file tab, taken by
/// its text view or, for an image or a notice, the view behind it.
extension NSView {
  func takeKeyboard(ifAskedBy model: AppModel, for tabID: FileTab.ID) {
    guard model.takeFileTabFocusRequest(tabID) else { return }
    // A turn later, once the view is in its window.
    Task { @MainActor in takeFirstResponder() }
  }
}

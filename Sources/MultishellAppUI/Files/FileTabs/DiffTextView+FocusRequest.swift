import AppKit
import MultishellAppCore
import MultishellCore

/// The keyboard a reconcile or a closed find bar handed a file tab.
extension DiffTextView {
  func takeKeyboard(ifAskedBy model: AppModel, for tabID: FileTab.ID) {
    guard model.takeFileTabFocusRequest(tabID) else { return }
    // A turn later, once the view is in its window.
    Task { @MainActor in takeFirstResponder() }
  }
}

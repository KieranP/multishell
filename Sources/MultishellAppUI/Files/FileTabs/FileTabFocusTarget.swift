import MultishellAppCore
import MultishellCore
import SwiftUI

/// Behind an image or a notice: takes the keyboard a reconcile hands its tab,
/// and reports a click into it, as a text view does.
struct FileTabFocusTarget: NSViewRepresentable {
  let model: AppModel
  let tabID: FileTab.ID

  func makeNSView(context: Context) -> FileTabFocusTargetView {
    FileTabFocusTargetView()
  }

  func updateNSView(_ view: FileTabFocusTargetView, context: Context) {
    view.onFocus = { [weak model] in model?.noteFileTabFocused(tabID) }
    view.takeKeyboard(ifAskedBy: model, for: tabID)
  }
}

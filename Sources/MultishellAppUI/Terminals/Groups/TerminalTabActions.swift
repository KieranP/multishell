import MultishellAppCore
import MultishellCore
import SwiftUI

/// A tab's context menu. A view of its own, so its lookups run when the menu
/// does rather than on every render of the strip.
struct TerminalTabActions: View {
  let model: AppModel
  let tab: TerminalTab

  var body: some View {
    Button(t("action.rename")) { model.beginRenamingTab(tab.id) }
    if tab.customTitle != nil {
      Button(t("tab.use-shell-title")) { model.renameTab(tab.id, to: nil) }
    }
    if model.state(of: tab) != nil {
      Divider()
      Button(t("action.clear-status")) { model.clearState(of: tab) }
    }
    Divider()
    TabMoveAndCloseActions(model: model, tabID: tab.id, groupID: tab.groupID)
  }
}

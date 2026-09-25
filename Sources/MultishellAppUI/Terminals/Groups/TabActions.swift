import MultishellAppCore
import MultishellCore
import SwiftUI

/// A tab's context menu. A view of its own, so its lookups run when the menu
/// does rather than on every render of the strip.
struct TabActions: View {
  let model: AppModel
  let group: TabGroup
  let tab: TerminalTab
  let canLeaveGroup: Bool

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
    // The keyboard-only way to the layout the edge bands offer a drag, and
    // only where it would do something.
    Button(t("tab.move-to-new-group")) {
      model.moveTab(tab.id, .after, toNewGroupOf: group.id)
    }
    .disabled(!canLeaveGroup)
    Divider()
    // The one way to close an inactive tab without a mouse, the X being
    // drawn on the active one alone. Not destructive-red.
    Button(t("tab.close")) { model.closeTab(tab.id) }
  }
}

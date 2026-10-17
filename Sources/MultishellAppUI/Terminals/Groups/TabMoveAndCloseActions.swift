import MultishellAppCore
import MultishellCore
import SwiftUI

/// The end of either kind of tab's context menu: a group of its own, and close.
struct TabMoveAndCloseActions: View {
  let model: AppModel
  let tabID: WorkspaceTab.ID
  let groupID: TabGroup.ID

  var body: some View {
    // The keyboard-only way to the layout the edge bands offer a drag, and
    // only where it would do something.
    Button(t("tab.move-to-new-group")) {
      model.moveTab(tabID, .after, toNewGroupOf: groupID)
    }
    .disabled(!model.canMoveTabToNewGroup(from: groupID))
    Divider()
    // The one way to close an inactive tab without a mouse, the X being
    // drawn on the active one alone. Not destructive-red.
    Button(t("tab.close")) { model.closeTab(tabID) }
  }
}

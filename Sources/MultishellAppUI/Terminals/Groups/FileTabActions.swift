import MultishellAppCore
import MultishellCore
import SwiftUI

/// A file tab's context menu: no rename, no status to clear, a file tab
/// keeping its file's name and running nothing.
struct FileTabActions: View {
  let model: AppModel
  let tab: FileTab

  var body: some View {
    FileActions(model: model, worktreeID: tab.worktreeID, path: tab.path)
    Divider()
    TabMoveAndCloseActions(model: model, tabID: tab.id, groupID: tab.groupID)
  }
}

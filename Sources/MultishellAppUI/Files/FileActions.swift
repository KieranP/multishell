import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a file or folder of a worktree offers, on a Files panel row's context
/// menu and a file tab's bar alike.
struct FileActions: View {
  let model: AppModel
  let worktreeID: Worktree.ID
  /// Relative to the worktree.
  let path: String

  var body: some View {
    Button(t("action.open-in-editor")) { model.openInEditor(path: path, in: worktreeID) }
    Button(t("action.reveal-in-finder")) { model.revealInFileBrowser(path: path, in: worktreeID) }
    Divider()
    Button(t("action.copy-path")) { model.copyPath(path, in: worktreeID) }
  }
}

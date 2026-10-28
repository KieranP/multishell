import MultishellAppCore
import MultishellCore
import SwiftUI

/// The window's right-hand panel: the worktree's files, what git says changed,
/// its pull request or its CI runs; see Docs/design/files.md and services.md.
struct FilesPanel: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  var body: some View {
    VStack(spacing: 0) {
      FilesPanelHeader(model: model, theme: theme)
      switch model.shownFilesPanelMode {
      case .ciRuns:
        CIPanelPage(model: model, worktree: worktree, theme: theme)

      case .files, .changes:
        FileListPage(model: model, worktree: worktree, theme: theme)

      case .pullRequest:
        PullRequestPanelPage(model: model, worktree: worktree, theme: theme)
      }
    }
    .background(theme.filesPanel.background)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(t("files-panel.title"))
    .task(id: worktree.id) { model.readFilesPanel(of: worktree.id) }
  }
}

import MultishellAppCore
import MultishellCore
import SwiftUI

/// The window's right-hand panel: files, changes, review comments, pull request or
/// CI runs; see Docs/design/files/panel.md and services/marks-and-pages.md.
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

      case .review:
        ReviewPanelPage(model: model, worktree: worktree, theme: theme)
      }
    }
    .background(theme.filesPanel.background)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(t("files-panel.title"))
    .task(id: worktree.id) { model.readFilesPanel(of: worktree.id) }
  }
}

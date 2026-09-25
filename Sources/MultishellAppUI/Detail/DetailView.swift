import MultishellAppCore
import MultishellCore
import SwiftUI

struct DetailView: View {
  let model: AppModel

  var body: some View {
    let theme = model.currentTheme
    VStack(spacing: 0) {
      switch model.detailContent {
      case .agentBoard:
        AgentBoardView(model: model, theme: theme)
      case .operation(let worktree, let operation):
        WorktreeHeader(model: model, worktree: worktree, theme: theme)
        WorktreeOperationView(
          operation: operation, theme: theme,
          cancel: { model.cancelStage(of: worktree) },
          dismiss: { model.dismissOperationFailure(of: worktree) })
      case .tabGroups(let worktree):
        WorktreeHeader(model: model, worktree: worktree, theme: theme)
        WorktreeTabGroups(model: model, worktree: worktree, theme: theme)
      case .noTabs(let worktree):
        WorktreeHeader(model: model, worktree: worktree, theme: theme)
        Spacer()
      case .noSelection(let hasProjects):
        // Clears the title-bar band, like the header does.
        Color.clear.windowHeader()
        NoSelectionPlaceholder(hasProjects: hasProjects, theme: theme) {
          Task { await model.chooseProject() }
        }
      }
    }
    // The widest sidebar leaves less than the header needs. Clipped from the
    // leading side, so the actions menu is what stays in view.
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
    .clipped()
    .background(theme.backgroundColor)
  }
}

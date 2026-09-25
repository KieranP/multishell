import MultishellAppCore
import MultishellCore
import SwiftUI

struct DetailView: View {
  let model: AppModel

  var body: some View {
    let theme = model.currentTheme
    VStack(spacing: 0) {
      // The board first: it fills the detail area in place of the selected
      // worktree's terminals, whose shells stay live behind it.
      if model.showsAgentBoard {
        AgentBoardView(model: model, theme: theme)
      } else if let worktree = model.workspace.selectedWorktree {
        WorktreeHeader(model: model, worktree: worktree, theme: theme)
        if let operation = model.worktreeOperations[worktree.id] {
          // In place of the terminals: a create has none yet, and a
          // remove is about to close them.
          WorktreeOperationView(
            operation: operation, theme: theme,
            cancel: { model.cancelStage(of: worktree) },
            dismiss: { model.dismissOperationFailure(of: worktree) })
        } else if !model.workspace.groups(in: worktree.id).isEmpty {
          TabColumnsView(model: model, worktree: worktree, theme: theme)
        } else {
          Spacer()
        }
      } else {
        // Clears the title-bar band, like the header does.
        Color.clear.frame(height: UIMetrics.headerHeight).titleBarDoubleClick()
        EmptyStateView(hasProjects: !model.workspace.projects.isEmpty, theme: theme) {
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

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
        toolbar(worktree, theme: theme)
        if let operation = model.worktreeOperations[worktree.id] {
          // In place of the terminals: a create has none yet, and a
          // remove is about to close them.
          WorktreeOperationView(
            operation: operation, theme: theme,
            cancel: { model.cancelStage(of: worktree) },
            dismiss: { model.dismissOperationFailure(of: worktree) })
        } else if !model.workspace.groups(in: worktree.id).isEmpty {
          TabGroupsView(model: model, worktree: worktree, theme: theme)
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
    .background(theme.backgroundColor)
  }

  /// One line: project › name, the branch under a renamed one, the path, the
  /// actions menu. The path gives way first; the names never do.
  private func toolbar(_ worktree: Worktree, theme: Theme) -> some View {
    let project = model.workspace.project(worktree.projectID)
    return HStack(spacing: 6) {
      if let project {
        ProjectIconView(
          settings: model.effectiveSettings(for: project),
          isMissing: model.missingProjects.contains(project.id),
          theme: theme, size: model.metrics.icon)
      }
      Text(project?.name ?? "")
        .font(.system(size: model.metrics.body, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
        .lineLimit(1)
        .layoutPriority(1)
      Image(systemName: "chevron.right")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(theme.textTertiary)
      Text(model.displayName(of: worktree))
        .font(.system(size: model.metrics.mono, weight: .medium, design: .monospaced))
        .foregroundStyle(theme.ansiRGB[6].color)
        .lineLimit(1)
        .layoutPriority(1)
      // A renamed worktree still says which branch it is: every git command
      // the user runs here acts on that, not on the name they chose.
      if model.customName(of: worktree) != nil {
        Text(worktree.name)
          .font(.system(size: model.metrics.caption, design: .monospaced))
          .foregroundStyle(theme.textTertiary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      Text(worktree.path.path.abbreviatingHomeDirectory())
        .font(.system(size: model.metrics.caption, design: .monospaced))
        .foregroundStyle(theme.textTertiary)
        .lineLimit(1)
        .truncationMode(.head)
        .padding(.leading, 6)
      Spacer(minLength: 8)
      actionsMenu(worktree, theme: theme)
    }
    .padding(.horizontal, 14)
    .frame(height: UIMetrics.headerHeight)
    .background(theme.chromeColor)
    .titleBarDoubleClick()
  }

  /// Everything that acts on the selected worktree, in one place a new user
  /// can find; the sidebar's context menu has the same items.
  private func actionsMenu(_ worktree: Worktree, theme: Theme) -> some View {
    Menu {
      WorktreeActions(model: model, worktree: worktree)
    } label: {
      Image(systemName: "ellipsis.circle")
        .font(.system(size: 13, weight: .medium))
        .frame(width: 30, height: 26)
        .contentShape(.rect)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .foregroundStyle(theme.textSecondary)
    .help(t("actions.worktree-actions"))
    .accessibilityLabel(t("actions.worktree-actions"))
  }
}

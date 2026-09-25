import MultishellAppCore
import MultishellCore
import SwiftUI

/// One line: project › name, the branch under a renamed one, the path, the
/// actions menu. The path gives way first; the names never do.
struct WorktreeHeader: View {
  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  var body: some View {
    let project = model.workspace.project(worktree.projectID)
    HStack(spacing: 6) {
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
        .foregroundStyle(theme.worktreeNameColor)
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
      actionsMenu
    }
    .windowHeader(fill: theme.chromeColor)
  }

  /// Everything that acts on the selected worktree, in one place a new user
  /// can find; the sidebar's context menu has the same items.
  private var actionsMenu: some View {
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
    .help(t("action.worktree-actions"))
    .accessibilityLabel(t("action.worktree-actions"))
  }
}

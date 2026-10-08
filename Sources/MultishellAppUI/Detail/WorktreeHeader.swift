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
          ringFill: theme.chromeColor, theme: theme, size: model.metrics.glyph)
      }
      WorktreeBreadcrumb(
        projectName: project?.name ?? "", worktreeName: model.displayName(of: worktree),
        style: .header, theme: theme, metrics: model.metrics)
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
      HeaderGlyph(symbol: "ellipsis.circle")
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

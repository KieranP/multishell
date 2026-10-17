import MultishellAppCore
import MultishellCore
import SwiftUI

/// Project › name, a renamed one's branch, the path, the actions menu and the
/// Files toggle. The path gives way first; the names never do.
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
          theme: theme,
          palette: theme.header,
          size: model.metrics.glyph,
        )
      }
      WorktreeBreadcrumb(
        projectName: project?.name ?? "",
        worktreeName: model.displayName(of: worktree),
        style: .header,
        theme: theme,
        metrics: model.metrics,
      )
      // A renamed worktree still says which branch it is: every git command
      // the user runs here acts on that, not on the name they chose.
      if model.customName(of: worktree) != nil {
        Text(worktree.name)
          .font(.system(size: model.metrics.caption, design: .monospaced))
          .foregroundStyle(theme.header.textTertiary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      Text(worktree.path.path.abbreviatingHomeDirectory())
        .font(.system(size: model.metrics.caption, design: .monospaced))
        .foregroundStyle(theme.header.textTertiary)
        .lineLimit(1)
        .truncationMode(.head)
        .padding(.leading, 6)
      Spacer(minLength: 8)
      actionsMenu
      filesToggle
    }
    .windowHeader(fill: theme.header.background)
  }

  /// Shows the Files panel on the window's right, in the header's accent
  /// while it is open. Drawn only where the panel can be.
  @ViewBuilder
  private var filesToggle: some View {
    if model.filesPanelWorktree != nil {
      PlainGlyphButton(help: t("files-panel.toggle-help")) {
        model.toggleFilesPanel()
      } glyph: {
        HeaderGlyph(symbol: "sidebar.right")
          .contentShape(.rect)
      }
      .foregroundStyle(
        model.showsFilesPanel
          ? theme.color(.accent, in: .header) : theme.header.textSecondary
      )
      .accessibilityLabel(t("files-panel.toggle"))
      .accessibilityAddTraits(model.showsFilesPanel ? .isSelected : [])
    }
  }

  /// Everything that acts on the selected worktree, in one place a new user
  /// can find; the sidebar's context menu has the same items.
  private var actionsMenu: some View {
    HeaderActionsMenu(help: t("action.worktree-actions"), palette: theme.header) {
      WorktreeActions(model: model, worktree: worktree)
    }
  }
}

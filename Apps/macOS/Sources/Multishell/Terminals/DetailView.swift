import MultishellCore
import SwiftUI

struct DetailView: View {
  let model: AppModel

  var body: some View {
    let theme = model.currentTheme
    VStack(spacing: 0) {
      if let worktree = model.workspace.selectedWorktree {
        toolbar(worktree, theme: theme)
        if let tab = model.workspace.activeTab(in: worktree.id) {
          TabBar(
            model: model,
            tabs: model.workspace.tabs(in: worktree.id),
            activeID: tab.id,
            theme: theme
          )
          PaneTreeView(
            model: model,
            tabID: tab.id,
            node: tab.root,
            focusedSessionID: tab.focusedSessionID,
            isSplit: tab.isSplit,
            theme: theme
          )
          .id(tab.id)
        } else {
          Spacer()
        }
      } else {
        // Room for the traffic lights, which sit over this corner.
        Color.clear.frame(height: 52).titleBarDoubleClick()
        EmptyStateView(hasProjects: !model.workspace.projects.isEmpty, theme: theme) {
          Task { await model.chooseProject() }
        }
      }
    }
    .background(theme.backgroundColor)
  }

  private func toolbar(_ worktree: Worktree, theme: Theme) -> some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 5) {
          Text(model.workspace.project(worktree.projectID)?.name ?? "")
            .font(.system(size: model.metrics.body, weight: .semibold))
            .foregroundStyle(theme.textPrimary)
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(theme.textTertiary)
          Text(worktree.name)
            .font(.system(size: model.metrics.mono, weight: .medium, design: .monospaced))
            .foregroundStyle(theme.ansiRGB[6].color)
          copyButton(worktree.name, help: "Copy branch name", theme: theme)
        }
        HStack(spacing: 5) {
          Text(worktree.path.path.abbreviatingHomeDirectory())
            .font(.system(size: model.metrics.caption, design: .monospaced))
            .foregroundStyle(theme.textTertiary)
            .lineLimit(1)
            .truncationMode(.head)
          copyButton(worktree.path.path, help: "Copy path", theme: theme)
        }
      }
      Spacer()
      if model.preferredAgentID(for: worktree) != nil {
        toolbarButton("sparkles", help: "New Agent Tab (⌥⌘T)") { model.newAgentTab() }
      }
      if model.workspace.activeTab(in: worktree.id) == nil {
        toolbarButton("plus", help: "New Tab (⌘T)") { model.newTab() }
      }
    }
    .padding(.horizontal, 14)
    .frame(height: 52)
    .background(theme.chromeColor)
    .titleBarDoubleClick()
  }

  /// With the title bar hidden the traffic lights sit at the window's top
  /// left, over whatever is there. When the sidebar is gone that is this
  /// toolbar, so the toggle steps right to clear them.
  private func toolbarButton(
    _ symbol: String, help: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 13, weight: .medium))
        .frame(width: 30, height: 26)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .foregroundStyle(model.currentTheme.textSecondary)
    .help(help)
  }

  private func copyButton(_ text: String, help: String, theme: Theme) -> some View {
    Button {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    } label: {
      Image(systemName: "doc.on.doc")
        .font(.system(size: 9.5))
        .foregroundStyle(theme.textTertiary)
        .frame(width: 20, height: 20)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(help)
  }
}

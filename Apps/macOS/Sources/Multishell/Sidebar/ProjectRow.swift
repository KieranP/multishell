import MultishellAppCore
import MultishellCore
import SwiftUI

/// A project in the sidebar: its chevron, icon, name, and the + that
/// starts a new worktree. Its worktrees are `WorktreeRow`s below it.
struct ProjectRow: View {
  let project: Project
  /// The project's settings with its repository's own filled in, for the
  /// icon.
  let settings: ProjectSettings
  let isMissing: Bool
  let state: SessionState?
  let worktreeCount: Int
  /// A `git fetch` is running here. The one thing this app does that waits
  /// on a network, so it is the one thing the sidebar has to show waiting.
  let isFetching: Bool
  let theme: Theme
  let metrics: UIMetrics
  let toggle: () -> Void
  let newWorktree: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 6) {
      // Only the chevron, icon and name toggle. A row-wide target made a
      // slightly-missed click on the + collapse the project instead.
      HStack(spacing: 6) {
        Image(systemName: "chevron.right")
          .font(.system(size: metrics.badge - 1, weight: .bold))
          .rotationEffect(.degrees(project.isExpanded ? 90 : 0))
          .foregroundStyle(theme.textTertiary)
          .frame(width: 10)
          .help(project.isExpanded ? t("sidebar.collapse") : t("sidebar.expand"))

        if isFetching {
          // The icon's own slot, like the dot below it, so nothing shifts
          // and no control is taken away while it spins.
          ProgressView()
            .controlSize(.mini)
            .scaleEffect(0.7)
            .frame(width: metrics.icon + 6)
            .help(t("sidebar.fetching"))
        } else if let state {
          Circle()
            .fill(theme.color(for: state))
            .frame(width: 7, height: 7)
            .frame(width: metrics.icon + 6)
            .help(t("sidebar.collapsed-state", state.displayName))
        } else {
          ProjectIconView(
            settings: settings, isMissing: isMissing, theme: theme, size: metrics.icon
          )
          .help(project.path.path)
        }

        Text(project.name)
          .font(.system(size: metrics.body, weight: .medium))
          .foregroundStyle(theme.textPrimary)
          .lineLimit(1)
          .opacity(isMissing ? 0.5 : 1)
          .help(isMissing ? t("sidebar.not-reachable", project.path.path) : "")
      }
      .frame(height: metrics.rowHeight)
      .contentShape(.rect)
      .onTapGesture(perform: toggle)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        AccessibilityText.project(
          name: project.name, isExpanded: project.isExpanded, isMissing: isMissing, state: state,
          worktreeCount: worktreeCount, isFetching: isFetching)
      )
      .accessibilityAddTraits(.isButton)
      .accessibilityAction(
        named: project.isExpanded ? t("sidebar.collapse") : t("sidebar.expand"), toggle)

      Spacer(minLength: 4)

      rowButton("plus", help: t("sidebar.new-worktree"), action: newWorktree)
    }
    .padding(.horizontal, 8)
    .frame(height: metrics.rowHeight)
    .onHover { isHovered = $0 }
  }

  private func rowButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: metrics.icon))
        .foregroundStyle(isHovered ? theme.textSecondary : theme.textTertiary)
        .frame(width: 24, height: 24)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(help)
    .accessibilityLabel(help)
  }
}

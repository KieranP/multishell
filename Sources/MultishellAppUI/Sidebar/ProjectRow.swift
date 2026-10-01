import MultishellAppCore
import MultishellCore
import SwiftUI

/// A project in the sidebar: its chevron, icon, name, and the + that
/// starts a new worktree. Its worktrees are `WorktreeRow`s below it.
struct ProjectRow: View {
  let project: Project
  /// What is on screen, which the filter can hold open over the stored flag.
  let isExpanded: Bool
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
      toggleArea

      Spacer(minLength: 4)

      newWorktreeButton
    }
    .padding(.horizontal, 8)
    .frame(height: metrics.rowHeight)
    .onHover { isHovered = $0 }
  }

  /// Only the chevron, icon and name toggle. A row-wide target made a
  /// slightly-missed click on the + collapse the project instead.
  private var toggleArea: some View {
    HStack(spacing: 6) {
      Image(systemName: "chevron.right")
        .font(.system(size: metrics.badge - 1, weight: .bold))
        .rotationEffect(.degrees(isExpanded ? 90 : 0))
        .foregroundStyle(theme.textTertiary)
        .frame(width: 10)
        .help(isExpanded ? t("sidebar.collapse") : t("sidebar.expand"))

      if isFetching {
        // The icon's own slot, like the dot below it, so nothing shifts
        // and no control is taken away while it spins.
        ProgressView()
          .controlSize(.mini)
          .scaleEffect(0.7)
          .frame(width: metrics.icon + 6)
          .help(t("sidebar.fetching"))
      } else if let state {
        StateDot(state: state, theme: theme)
          .frame(width: metrics.icon + 6)
          .help(t("sidebar.collapsed-state", state.displayName))
      } else {
        ProjectIconView(
          settings: settings, isMissing: isMissing, ringFill: theme.sidebarColor, theme: theme,
          size: metrics.icon
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
        name: project.name, isExpanded: isExpanded, isMissing: isMissing, state: state,
        worktreeCount: worktreeCount, isFetching: isFetching)
    )
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(
      named: isExpanded ? t("sidebar.collapse") : t("sidebar.expand"), toggle)
  }

  private var newWorktreeButton: some View {
    PlainGlyphButton(help: t("sidebar.new-worktree"), action: newWorktree) {
      Image(systemName: "plus")
        .font(.system(size: metrics.icon))
        .foregroundStyle(isHovered ? theme.textSecondary : theme.textTertiary)
        .frame(width: UIMetrics.sidebarRowButtonWidth, height: UIMetrics.sidebarRowButtonWidth)
    }
  }
}

/// Everything but the closures, which capture only the project; see
/// `WorktreeRow`'s.
extension ProjectRow: @MainActor Equatable {
  static func == (a: ProjectRow, b: ProjectRow) -> Bool {
    a.project == b.project && a.isExpanded == b.isExpanded && a.settings == b.settings
      && a.isMissing == b.isMissing
      && a.state == b.state && a.worktreeCount == b.worktreeCount
      && a.isFetching == b.isFetching && a.theme == b.theme && a.metrics == b.metrics
  }
}

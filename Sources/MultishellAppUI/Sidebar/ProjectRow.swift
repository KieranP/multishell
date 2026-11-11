import MultishellAppCore
import MultishellCore
import SwiftUI

/// A project in the sidebar: its chevron, icon, name, and the + that
/// starts a new worktree. Its worktrees are `WorktreeRow`s below it.
struct ProjectRow: View, @MainActor Equatable {
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
  let toggleExpansion: () -> Void
  let requestNewWorktree: () -> Void

  @State private var isHovered = false
  @State private var isNewWorktreeButtonHovered = false

  var body: some View {
    HStack(spacing: 6) {
      toggleArea

      Spacer(minLength: 4)

      newWorktreeButton
    }
    .padding(.horizontal, UIMetrics.sidebarRowSideInset)
    .frame(height: metrics.rowHeight)
    .tracksHover($isHovered)
  }

  /// Only the chevron, icon and name toggle. A row-wide target made a
  /// slightly-missed click on the + collapse the project instead.
  private var toggleArea: some View {
    HStack(spacing: 6) {
      DisclosureChevron(
        isExpanded: isExpanded,
        size: metrics.small,
        weight: .bold,
        metrics: metrics,
      )
      .foregroundStyle(theme.projectsPanel.textTertiary)
      .frame(width: 10)
      .help(expansionActionName)

      switch ProjectRowSlot(isFetching: isFetching, state: state) {
      case .fetching:
        // The icon's own slot, like the dot below it, so nothing shifts
        // and no control is taken away while it spins.
        ProgressView()
          .controlSize(.mini)
          .scaleEffect(0.7)
          .frame(width: UIMetrics.projectIconSlot(forGlyphOf: metrics.glyph))
          .help(t("sidebar.fetching"))

      case .state(let state):
        StateDot(state: state, theme: theme, palette: theme.projectsPanel)
          .frame(width: UIMetrics.projectIconSlot(forGlyphOf: metrics.glyph))
          .help(t("sidebar.collapsed-state", state.displayName))

      case .icon:
        ProjectIconView(
          settings: settings,
          isMissing: isMissing,
          theme: theme,
          palette: theme.projectsPanel,
          size: metrics.glyph,
        )
        .help(project.path.path)
      }

      Text(project.name)
        .font(metrics.font(size: metrics.bodySize, weight: .medium))
        .foregroundStyle(theme.projectsPanel.text)
        .lineLimit(1)
        .opacity(isMissing ? 0.5 : 1)
        .help(isMissing ? t("sidebar.not-reachable", project.path.path) : "")
    }
    .frame(height: metrics.rowHeight)
    .contentShape(.rect)
    .onTapGesture(perform: toggleExpansion)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AccessibilityText.project(
        name: project.name,
        isExpanded: isExpanded,
        isMissing: isMissing,
        state: state,
        worktreeCount: worktreeCount,
        isFetching: isFetching,
      )
    )
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: expansionActionName, toggleExpansion)
  }

  private var expansionActionName: String {
    isExpanded ? t("sidebar.collapse") : t("sidebar.expand")
  }

  private var newWorktreeButton: some View {
    // Unlit by the click, the row with it, as the sheet it opens hides the exit.
    PlainGlyphButton(help: t("sidebar.new-worktree")) {
      isNewWorktreeButtonHovered = false
      isHovered = false
      requestNewWorktree()
    } glyph: {
      Image(systemName: "plus")
        .font(metrics.font(size: metrics.glyph))
        // No taller than the row, so its lit square stays off the rows beside it.
        .frame(
          width: UIMetrics.sidebarRowButtonWidth,
          height: min(UIMetrics.sidebarRowButtonWidth, metrics.rowHeight),
        )
        // Brighter while the row is pointed at, lit once the + itself is.
        .glyphHover(
          isNewWorktreeButtonHovered,
          palette: theme.projectsPanel,
          resting: isHovered ? theme.projectsPanel.textSecondary : theme.projectsPanel.textTertiary,
        )
        .accessibilityHidden(true)
    }
    .tracksHover($isNewWorktreeButtonHovered)
  }

  /// Everything but the closures, which capture only the project; see
  /// `WorktreeRow`'s.
  static func == (a: Self, b: Self) -> Bool {
    a.project == b.project && a.isExpanded == b.isExpanded && a.settings == b.settings
      && a.isMissing == b.isMissing
      && a.state == b.state && a.worktreeCount == b.worktreeCount
      && a.isFetching == b.isFetching && a.theme == b.theme && a.metrics == b.metrics
  }
}

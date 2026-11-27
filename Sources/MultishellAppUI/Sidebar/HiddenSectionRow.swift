import MultishellAppCore
import MultishellCore
import SwiftUI

/// The row under a project's worktrees that holds the ones the user hid,
/// collapsed until its chevron is clicked. See Docs/design/worktrees/sidebar.md.
struct HiddenSectionRow: View, @MainActor Equatable {
  let isExpanded: Bool
  let worktreeCount: Int
  /// Its worktrees' most urgent dot while they are collapsed away.
  let state: SessionState?
  let theme: Theme
  let metrics: UIMetrics
  let toggleExpansion: () -> Void

  var body: some View {
    HStack(spacing: UIMetrics.sidebarGlyphGap) {
      DisclosureChevron(
        isExpanded: isExpanded,
        size: metrics.small,
        weight: .bold,
        metrics: metrics,
      )
      .frame(width: metrics.sidebarGlyphColumn)
      Text(t("sidebar.hidden"))
        .font(metrics.font(size: metrics.secondary))
      Text("\(worktreeCount)")
        .font(metrics.font(size: metrics.badge))
        .monospacedDigit()
      if let state {
        StateDot(state: state, theme: theme, palette: theme.projectsPanel)
          .help(t("sidebar.collapsed-state", state.displayName))
      }
      Spacer(minLength: 0)
    }
    .foregroundStyle(theme.projectsPanel.textTertiary)
    .padding(.leading, metrics.worktreeRowIndent)
    .padding(.trailing, UIMetrics.sidebarRowSideInset)
    .frame(height: metrics.rowHeight)
    .contentShape(.rect)
    .onTapGesture(perform: toggleExpansion)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AccessibilityText.hiddenSection(
        isExpanded: isExpanded,
        worktreeCount: worktreeCount,
        state: state,
      )
    )
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(
      named: isExpanded ? t("sidebar.collapse") : t("sidebar.expand"),
      toggleExpansion,
    )
  }

  /// Everything but the closure, which captures only the project.
  static func == (a: Self, b: Self) -> Bool {
    a.isExpanded == b.isExpanded && a.worktreeCount == b.worktreeCount && a.state == b.state
      && a.theme == b.theme && a.metrics == b.metrics
  }
}

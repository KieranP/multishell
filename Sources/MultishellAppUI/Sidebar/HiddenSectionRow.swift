import MultishellAppCore
import MultishellCore
import SwiftUI

/// The row under a project's worktrees that holds the ones the user hid,
/// collapsed until its chevron is clicked. See Docs/design/worktrees/sidebar.md.
struct HiddenSectionRow: View, @MainActor Equatable {
  let isExpanded: Bool
  let worktreeCount: Int
  let theme: Theme
  let metrics: UIMetrics
  let toggleExpansion: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "chevron.right")
        .font(metrics.font(size: metrics.small, weight: .bold))
        .rotationEffect(.degrees(isExpanded ? 90 : 0))
        .frame(width: metrics.sidebarGlyphColumn)
      Text(t("sidebar.hidden"))
        .font(metrics.font(size: metrics.secondary))
      Text("\(worktreeCount)")
        .font(metrics.font(size: metrics.badge))
        .monospacedDigit()
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
      AccessibilityText.hiddenSection(isExpanded: isExpanded, worktreeCount: worktreeCount)
    )
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(
      named: isExpanded ? t("sidebar.collapse") : t("sidebar.expand"),
      toggleExpansion,
    )
  }

  /// Everything but the closure, which captures only the project.
  static func == (a: Self, b: Self) -> Bool {
    a.isExpanded == b.isExpanded && a.worktreeCount == b.worktreeCount && a.theme == b.theme
      && a.metrics == b.metrics
  }
}

import MultishellAppCore
import MultishellCore
import SwiftUI

/// The entry above Projects that opens the board, carrying the waiting,
/// working and done counts. Selected is the worktree rows' own outline.
struct SidebarAgentsRow: View {
  let counts: [AgentBoardLaneCount]
  let isSelected: Bool
  let theme: Theme
  let metrics: UIMetrics
  let select: () -> Void

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "square.grid.2x2")
        .font(.system(size: metrics.glyph, weight: .medium))
        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
        .frame(width: metrics.sidebarGlyphColumn)
      Text(t("label.agents"))
        .font(.system(size: metrics.secondary, weight: .medium))
        .foregroundStyle(theme.rowNameColor(isSelected: isSelected))
        .lineLimit(1)
      Spacer(minLength: 4)
      ForEach(counts, id: \.lane) { entry in
        HStack(spacing: 3) {
          StateDot(
            state: entry.lane.headerState, theme: theme, diameter: UIMetrics.inlineStateDotDiameter)
          Text("\(entry.count)")
            .font(.system(size: metrics.badge, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(theme.textSecondary)
        }
      }
    }
    .padding(.horizontal, 8)
    .frame(height: metrics.rowHeight)
    .rowSelection(isSelected: isSelected)
    .contentShape(.rect)
    .onTapGesture(perform: select)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.agentsRow(counts))
    .selectableButtonTraits(isSelected: isSelected)
  }
}

/// Everything but `select`, which captures only the model; see `WorktreeRow`'s.
extension SidebarAgentsRow: @MainActor Equatable {
  static func == (a: SidebarAgentsRow, b: SidebarAgentsRow) -> Bool {
    a.counts == b.counts && a.isSelected == b.isSelected && a.theme == b.theme
      && a.metrics == b.metrics
  }
}

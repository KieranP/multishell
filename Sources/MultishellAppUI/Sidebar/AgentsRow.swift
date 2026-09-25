import MultishellAppCore
import MultishellCore
import SwiftUI

/// The entry above Projects that opens the board, carrying the waiting,
/// working and done counts. Selected is the worktree rows' own outline.
struct AgentsRow: View {
  let counts: [(lane: AgentBoardLane, count: Int)]
  let isSelected: Bool
  let theme: Theme
  let metrics: UIMetrics
  let select: () -> Void

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "square.grid.2x2")
        .font(.system(size: metrics.icon, weight: .medium))
        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
        .frame(width: metrics.icon + 2)
      Text(t("label.agents"))
        .font(.system(size: metrics.secondary, weight: .medium))
        .foregroundStyle(theme.textPrimary.opacity(isSelected ? 1 : 0.85))
        .lineLimit(1)
      Spacer(minLength: 4)
      ForEach(counts.filter { $0.count > 0 }, id: \.lane) { entry in
        HStack(spacing: 3) {
          StateDot(state: entry.lane.headerState, theme: theme, diameter: 6)
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
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

/// Everything but `select`, which captures nothing; see `WorktreeRow`'s.
extension AgentsRow: @MainActor Equatable {
  static func == (a: AgentsRow, b: AgentsRow) -> Bool {
    a.counts.elementsEqual(b.counts) { $0.lane == $1.lane && $0.count == $1.count }
      && a.isSelected == b.isSelected && a.theme == b.theme && a.metrics == b.metrics
  }
}

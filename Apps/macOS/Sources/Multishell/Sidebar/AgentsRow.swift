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
          Circle()
            .fill(theme.color(for: entry.lane.headerState))
            .frame(width: 6, height: 6)
          Text("\(entry.count)")
            .font(.system(size: metrics.badge, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(theme.textSecondary)
        }
      }
    }
    .padding(.horizontal, 8)
    .frame(height: metrics.rowHeight)
    .background(
      isSelected ? Color.accentColor.opacity(0.12) : .clear,
      in: RoundedRectangle(cornerRadius: 6)
    )
    .overlay {
      if isSelected {
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(Color.accentColor, lineWidth: 1.5)
      }
    }
    .contentShape(.rect)
    .onTapGesture(perform: select)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.agentsRow(counts))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

import MultishellAppCore
import MultishellCore
import SwiftUI

/// Under the chip: each worker by kind and how long it has been out, ticking
/// while the list is up. Not its tool, which flashed; see Docs/design/agents.md.
struct SubagentList: View {
  let subagents: [Subagent]
  let theme: Theme
  let metrics: UIMetrics

  @State private var now = Date()

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 5) {
        Image(systemName: "arrow.triangle.branch")
          .font(.system(size: metrics.badge - 1, weight: .semibold))
          .foregroundStyle(theme.color(for: .running))
        Text(subagents.countText)
          .font(.system(size: metrics.badge, weight: .semibold))
          .foregroundStyle(theme.textPrimary)
      }
      .padding(.bottom, 2)
      ForEach(subagents) { subagent in
        HStack(spacing: 7) {
          StateDot(state: .running, theme: theme, diameter: 6)
          Text(subagent.displayName)
            .font(.system(size: metrics.badge, weight: .medium))
            .foregroundStyle(theme.textPrimary)
            .lineLimit(1)
          if let occurrences = subagent.occurrenceText {
            Text(occurrences)
              .font(.system(size: metrics.badge - 1, weight: .medium))
              .monospacedDigit()
              .foregroundStyle(theme.textSecondary)
          }
          Spacer(minLength: 12)
          Text(subagent.elapsed(at: now) ?? "")
            .font(.system(size: metrics.badge - 1, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(theme.textTertiary)
            .frame(minWidth: 38, alignment: .trailing)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .frame(minWidth: 200, alignment: .leading)
    .background(theme.sidebarColor)
    .ticking($now, every: .seconds(1))
  }
}

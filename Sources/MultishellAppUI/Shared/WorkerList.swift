import MultishellAppCore
import MultishellCore
import SwiftUI

/// Under the chip: each worker by kind and how long it has been out, ticking
/// while the list is up. Not its tool, which flashed; see Docs/design/agents.md.
struct WorkerList: View {
  let workers: [Worker]
  let theme: Theme
  let metrics: UIMetrics

  @State private var now = Date()

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 5) {
        WorkerGlyph(metrics: metrics)
          .foregroundStyle(theme.color(for: .running))
        Text(workers.countText)
          .font(.system(size: metrics.badge, weight: .semibold))
          .foregroundStyle(theme.textPrimary)
      }
      .padding(.bottom, 2)
      ForEach(workers) { worker in
        HStack(spacing: 7) {
          StateDot(state: .running, theme: theme, diameter: UIMetrics.inlineStateDotDiameter)
          Text(worker.displayName)
            .font(.system(size: metrics.badge, weight: .medium))
            .foregroundStyle(theme.textPrimary)
            .lineLimit(1)
          if let occurrences = worker.occurrenceText {
            Text(occurrences)
              .font(.system(size: metrics.small, weight: .medium))
              .monospacedDigit()
              .foregroundStyle(theme.textSecondary)
          }
          Spacer(minLength: 12)
          Text(worker.elapsed(at: now) ?? "")
            .font(.system(size: metrics.small, design: .monospaced))
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

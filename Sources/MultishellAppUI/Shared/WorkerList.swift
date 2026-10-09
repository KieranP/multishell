import MultishellAppCore
import MultishellCore
import SwiftUI

/// Under the chip: each worker's name and description under its parent, and
/// its time out. Not its tool, which flashed; see Docs/design/agents.md.
struct WorkerList: View {
  private static let rowSpacing: CGFloat = 7
  /// A description runs to 200 characters, which is cut short of this.
  static let maximumWidth: CGFloat = 420
  /// A nested worker's dot sits under its parent's name.
  private static let nestingIndent = UIMetrics.inlineStateDotDiameter + rowSpacing

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
      ForEach(workers.nested) { nested in
        let worker = nested.worker
        HStack(spacing: Self.rowSpacing) {
          StateDot(
            state: worker.shownState,
            theme: theme,
            diameter: UIMetrics.inlineStateDotDiameter,
          )
          .padding(.leading, CGFloat(nested.depth) * Self.nestingIndent)
          Text(worker.displayName)
            .font(.system(size: metrics.badge, weight: .medium))
            .foregroundStyle(theme.textPrimary)
            .lineLimit(1)
          if let description = worker.description {
            Text(description)
              .font(.system(size: metrics.badge))
              .foregroundStyle(theme.textSecondary)
              .lineLimit(1)
              .truncationMode(.tail)
          }
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
    .frame(minWidth: 200, maxWidth: Self.maximumWidth, alignment: .leading)
    .background(theme.sidebarColor)
    .ticking($now, every: .seconds(1))
  }
}

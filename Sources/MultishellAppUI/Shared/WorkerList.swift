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

  private var palette: AreaPalette { theme.projectsPanel }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 5) {
        WorkerGlyph(metrics: metrics)
          .foregroundStyle(theme.color(for: .running, on: palette))
        Text(workers.countText)
          .font(metrics.font(size: metrics.badge, weight: .semibold))
          .foregroundStyle(palette.text)
      }
      .padding(.bottom, 2)
      ForEach(workers.nested) { nested in
        let worker = nested.worker
        HStack(spacing: Self.rowSpacing) {
          StateDot(
            state: worker.shownState,
            theme: theme,
            palette: palette,
            diameter: UIMetrics.inlineStateDotDiameter,
          )
          .padding(.leading, CGFloat(nested.depth) * Self.nestingIndent)
          Text(worker.displayName)
            .font(metrics.font(size: metrics.badge, weight: .medium))
            .foregroundStyle(palette.text)
            .lineLimit(1)
          if let description = worker.description {
            Text(description)
              .font(metrics.font(size: metrics.badge))
              .foregroundStyle(palette.textSecondary)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          if let occurrences = worker.occurrenceText {
            Text(occurrences)
              .font(metrics.font(size: metrics.small, weight: .medium))
              .monospacedDigit()
              .foregroundStyle(palette.textSecondary)
          }
          Spacer(minLength: 12)
          Text(worker.elapsed(at: now) ?? "")
            .font(.system(size: metrics.small, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(palette.textTertiary)
            .frame(minWidth: 38, alignment: .trailing)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .frame(minWidth: 200, maxWidth: Self.maximumWidth, alignment: .leading)
    .background(palette.background)
    .ticking($now, every: .seconds(1))
  }
}

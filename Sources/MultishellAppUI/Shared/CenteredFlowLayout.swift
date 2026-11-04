import MultishellAppCore
import SwiftUI

/// Its subviews in lines that wrap at the width offered, each line centred;
/// `FlowRows` decides which share a line.
struct CenteredFlowLayout: Layout {
  let spacing: Double

  func makeCache(subviews: Subviews) -> [CGSize] {
    subviews.map { $0.sizeThatFits(.unspecified) }
  }

  func updateCache(_ cache: inout [CGSize], subviews: Subviews) {
    cache = makeCache(subviews: subviews)
  }

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache sizes: inout [CGSize],
  ) -> CGSize {
    let rows = flowRows(of: sizes, within: proposal.width)
    let lines = rows.lines
    let width =
      zip(lines, rows.lineWidths).map { line, summed in
        drawnWidth(of: line, summed: summed, subviews: subviews, sizes: sizes, in: rows)
      }.max() ?? 0
    let height =
      lines.map { lineHeight(of: $0, in: sizes) }.reduce(0, +)
      + spacing * Double(max(lines.count - 1, 0))
    return CGSize(width: width, height: height)
  }

  /// Broken against the width proposed, as `sizeThatFits` was, not the bounds
  /// that came of it: rounded down, those could push a line's last view on.
  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache sizes: inout [CGSize],
  ) {
    var top = bounds.minY
    let rows = flowRows(of: sizes, within: proposal.width)
    for (line, summed) in zip(rows.lines, rows.lineWidths) {
      let height = lineHeight(of: line, in: sizes)
      let drawnWidths = line.map { drawnWidth(of: subviews[$0], sized: sizes[$0], in: rows) }
      let lineWidth = drawnWidth(
        of: line,
        summed: summed,
        subviews: subviews,
        sizes: sizes,
        in: rows,
      )
      var leading = bounds.midX - lineWidth / 2
      for (index, width) in zip(line, drawnWidths) {
        subviews[index].place(
          at: CGPoint(x: leading, y: top + (height - sizes[index].height) / 2),
          proposal: ProposedViewSize(width: width, height: sizes[index].height),
        )
        leading += width + spacing
      }
      top += height + spacing
    }
  }

  /// A line's width as its views draw it, summed as `FlowRows` broke it. Only a
  /// view alone on its line can be offered less than it asked, so only it is measured.
  private func drawnWidth(
    of line: Range<Int>,
    summed lineWidth: Double,
    subviews: Subviews,
    sizes: [CGSize],
    in rows: FlowRows,
  ) -> Double {
    guard line.count == 1, let index = line.first else { return lineWidth }
    return drawnWidth(of: subviews[index], sized: sizes[index], in: rows)
  }

  /// Its cached width where that fits, else what it draws at when offered less.
  private func drawnWidth(
    of subview: LayoutSubview,
    sized size: CGSize,
    in rows: FlowRows,
  ) -> Double {
    guard rows.isShownNarrower(than: size.width) else { return size.width }
    let shown = rows.shownWidth(of: size.width)
    return subview.sizeThatFits(ProposedViewSize(width: shown, height: size.height)).width
  }

  private func flowRows(of sizes: [CGSize], within width: CGFloat?) -> FlowRows {
    FlowRows(
      widths: sizes.map { Double($0.width) },
      maxWidth: width.map(Double.init) ?? .infinity,
      spacing: spacing,
    )
  }

  private func lineHeight(of line: Range<Int>, in sizes: [CGSize]) -> Double {
    sizes[line].map { Double($0.height) }.max() ?? 0
  }
}

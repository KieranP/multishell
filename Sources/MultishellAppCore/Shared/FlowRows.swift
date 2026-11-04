/// Which items share a line, laid left to right within a width: each line
/// takes as many as fit, and at least one however wide.
public struct FlowRows: Sendable {
  public let lines: [Range<Int>]
  /// Each line's width, summed as the breaking was, so a line offered exactly
  /// its own width is never broken again by a rounding the other way.
  public let lineWidths: [Double]
  private let maxWidth: Double

  public init(widths: [Double], maxWidth: Double, spacing: Double) {
    var lines: [Range<Int>] = []
    var lineWidths: [Double] = []
    var start = 0
    var lineWidth = 0.0
    for (index, width) in widths.enumerated() {
      let extended = index > start ? lineWidth + spacing + width : width
      if index > start, extended > maxWidth {
        lines.append(start..<index)
        lineWidths.append(lineWidth)
        start = index
        lineWidth = width
      } else {
        lineWidth = extended
      }
    }
    if start < widths.count {
      lines.append(start..<widths.count)
      lineWidths.append(lineWidth)
    }
    self.lines = lines
    self.lineWidths = lineWidths
    self.maxWidth = maxWidth
  }

  /// An item's width as shown, no wider than the width offered: only one alone on
  /// its line can be wider, and it is offered the line.
  public func shownWidth(of width: Double) -> Double {
    min(width, maxWidth)
  }

  /// Whether an item is shown narrower than it asked for, and so draws at a
  /// width it must be measured again for.
  public func isShownNarrower(than width: Double) -> Bool {
    shownWidth(of: width) < width
  }
}

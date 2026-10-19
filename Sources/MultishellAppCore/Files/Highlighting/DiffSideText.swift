/// One side of a file tab's rows as the highlighter parses it, its lines joined, with
/// where each line sits in that text and the row showing it.
public struct DiffSideText: Sendable {
  private static let lineSeparator = "\n"

  public let string: String
  let display: DiffDisplayText
  let side: DiffSide
  let lineRanges: [Range<Int>]
  let displayRows: [Int]

  public init(of display: DiffDisplayText, side: DiffSide) {
    var lines: [String] = []
    var lineRanges: [Range<Int>] = []
    var displayRows: [Int] = []
    var offset = 0
    for (row, line) in display.lines.enumerated() where side.shows(line.kind) {
      let end = offset + line.text.utf16.count
      lines.append(line.text)
      lineRanges.append(offset..<end)
      displayRows.append(row)
      offset = end + Self.lineSeparator.utf16.count
    }
    string = lines.joined(separator: Self.lineSeparator)
    self.display = display
    self.side = side
    self.lineRanges = lineRanges
    self.displayRows = displayRows
  }
}

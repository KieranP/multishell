/// Where a file tab's view was scrolled to, by the file's line at the top, so
/// a new font size or the other layout keeps the place; saved at quit.
public struct FileTabScroll: Codable, Hashable, Sendable {
  /// A renamed field keeps the key it was written under.
  private enum CodingKeys: String, CodingKey {
    case line, rowsFromLine, x
    case isCommittedLine = "isHEADsLine"
  }

  /// The top row's line, else the nearest after it, else before; 0 where no
  /// row has one, and `rowsFromLine` then counts from row 0.
  public let line: Int
  /// `line` is the committed side's numbering, the merge base's under Branch: the top row
  /// is one only that side has, which Split shows on its left.
  public let isCommittedLine: Bool
  /// The top row's distance from that line's row, a fraction where one is cut.
  public let rowsFromLine: Double
  /// Sideways, in points.
  public let x: Double

  public init(line: Int, isCommittedLine: Bool, rowsFromLine: Double, x: Double) {
    self.line = line
    self.isCommittedLine = isCommittedLine
    self.rowsFromLine = rowsFromLine
    self.x = x
  }
}

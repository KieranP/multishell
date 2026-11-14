import MultishellCore

/// Lines of one file kept open inside a fold, by their number on one side: a
/// fold the user opened, or a comment's lines and two either side.
public struct AllChangesLineSpan: Hashable, Sendable {
  public let side: DiffSide
  public let lines: ClosedRange<Int>

  public init(side: DiffSide, lines: ClosedRange<Int>) {
    self.side = side
    self.lines = lines
  }

  func holds(_ line: DiffLine) -> Bool {
    line.number(on: side).map(lines.contains) ?? false
  }
}

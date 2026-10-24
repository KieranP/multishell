/// A file tab's rows as one text, a row a line: what the view lays out, copies
/// from and searches. A 1 MiB file can be one line, so a line is capped.
public struct DiffDisplayText: Equatable, Sendable {
  /// Past this many UTF-16 units a line is cut and marked, so one line cannot
  /// make the view as wide as a megabyte of text.
  private static let lineLengthLimit = 10_000

  /// With each text capped.
  public let lines: [DiffLine]
  /// The lines joined by newlines, with none after the last.
  public let string: String
  /// Where each row starts in `string`, in UTF-16 units.
  public let rowStarts: [Int]
  /// The first row of each change, ascending: what a step lands on.
  let changeStarts: [Int]
  /// The sides every line of which these rows hold: a split side holds one, and
  /// a parse of the other's partial text would colour it wrong.
  let wholeSides: [DiffSide]
  /// Every committed line's text hashed, the merge base's under Branch (files.md), which a
  /// commit, checkout or new scope changes; a split's right side takes its left's.
  let committedDigest: Int
  /// Whether a changed line says staged or unstaged: not against an older
  /// commit than `HEAD`, whose changes the index holds too.
  public let marksStaging: Bool

  public init(_ lines: [DiffLine], marksStaging: Bool) {
    self.init(
      lines,
      wholeSides: [.committed, .onDisk],
      committedDigest: nil,
      marksStaging: marksStaging,
    )
  }

  /// `committedDigest` where already hashed, or for rows missing some committed lines.
  init(_ lines: [DiffLine], wholeSides: [DiffSide], committedDigest: Int?, marksStaging: Bool) {
    self.wholeSides = wholeSides
    self.marksStaging = marksStaging
    var starts: [Int] = []
    starts.reserveCapacity(lines.count)
    var offset = 0
    let capped = lines.map { line in
      starts.append(offset)
      let text = Self.capped(line.text)
      let length = text.utf16.count
      offset += length + 1
      return text == line.text
        ? line
        : DiffLine(
          kind: line.kind,
          oldNumber: line.oldNumber,
          newNumber: line.newNumber,
          text: text,
          isStaged: line.isStaged,
          changedParts: line.changedParts.map { $0.clamped(to: 0..<length) }.filter { !$0.isEmpty },
        )
    }
    self.lines = capped
    self.rowStarts = starts
    self.changeStarts = capped.indices.filter { row in
      capped[row].kind != .context && (row == 0 || capped[row - 1].kind == .context)
    }
    self.string = capped.map(\.text).joined(separator: "\n")
    self.committedDigest = committedDigest ?? Self.committedDigest(of: capped)
  }

  /// Hasher is seeded per launch, so a digest is never saved.
  private static func committedDigest(of lines: [DiffLine]) -> Int {
    var hasher = Hasher()
    for line in lines where line.oldNumber != nil { hasher.combine(line.text) }
    return hasher.finalize()
  }

  private static func capped(_ text: String) -> String {
    let units = text.utf16
    guard units.count > lineLengthLimit else { return text }
    let end = units.index(units.startIndex, offsetBy: lineLengthLimit)
    return String(text[..<end]) + "…"
  }

  /// The row holding a UTF-16 offset, the last row for one past the end.
  public func row(atOffset offset: Int) -> Int {
    max(0, rowStarts.partitioningIndex { $0 > offset } - 1)
  }

  /// A row's text, its newline left out, in UTF-16 units.
  public func range(ofRow row: Int) -> Range<Int> {
    let start = rowStarts[row]
    return start..<(start + lines[row].text.utf16.count)
  }

  /// The rows a range reaches into, a range ending at a row's start not
  /// reaching it; an empty range touches the row it sits in.
  public func rows(touching range: Range<Int>) -> ClosedRange<Int> {
    row(atOffset: range.lowerBound)...row(atOffset: max(range.lowerBound, range.upperBound - 1))
  }

  /// The text of a UTF-16 range, cut to `string`'s end.
  func text(in range: Range<Int>) -> String {
    let utf16 = string.utf16
    let lower = utf16.index(utf16.startIndex, offsetBy: min(range.lowerBound, utf16.count))
    let upper = utf16.index(utf16.startIndex, offsetBy: min(range.upperBound, utf16.count))
    return String(utf16[lower..<upper]) ?? ""
  }
}

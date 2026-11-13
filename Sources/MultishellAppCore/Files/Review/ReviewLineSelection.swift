import MultishellCore

/// The lines a drag down the gutter or a text selection picks, on one side.
public struct ReviewLineSelection: Equatable, Sendable {
  let side: DiffSide
  let lines: ClosedRange<Int>

  /// From the row a drag starts on to where it ends, up or down. `side` is a split
  /// column's; in Unified the start row picks it, so a range never mixes the two.
  public init?(from start: Int, to end: Int, in lines: [DiffLine], side: DiffSide? = nil) {
    guard !lines.isEmpty else { return nil }
    let rows = (min(start, end)...max(start, end)).clamped(to: 0...(lines.count - 1))
    let rowLines = rows.map { lines[$0] }
    let startLine =
      lines.indices.contains(start) && lines[start].kind != .padding
      ? lines[start] : nil
    let picker = startLine ?? rowLines.first { $0.kind != .padding }
    guard
      let wantedSide = side
        ?? picker.map({ line in line.kind == .removed ? DiffSide.committed : .onDisk })
    else { return nil }
    // Unchanged lines alone, even in a split's left column, are the file on disk's.
    let holdsRemoved = rowLines.contains { $0.kind == .removed }
    let pickedSide = wantedSide == .committed && !holdsRemoved ? DiffSide.onDisk : wantedSide
    let numbers = rowLines.compactMap { line in
      pickedSide.shows(line.kind) ? line.number(on: pickedSide) : nil
    }
    guard let first = numbers.min(), let last = numbers.max() else { return nil }
    self.side = pickedSide
    self.lines = first...last
  }
}

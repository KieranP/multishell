import MultishellCore

/// A file's held-open spans merged by side, so a build asks after each line by
/// halving them rather than walking every one: a comment holds five lines.
struct AllChangesHeldLines {
  private let committed: [ClosedRange<Int>]
  private let onDisk: [ClosedRange<Int>]

  /// A span past a side's last line in `lines` holds that line instead, where
  /// `ReviewCardPlacement` puts a card whose lines the file no longer reaches.
  init(_ spans: [AllChangesLineSpan], within lines: [DiffLine]) {
    committed = Self.merged(Self.clamped(spans, on: .committed, within: lines))
    onDisk = Self.merged(Self.clamped(spans, on: .onDisk, within: lines))
  }

  private static func clamped(
    _ spans: [AllChangesLineSpan],
    on side: DiffSide,
    within lines: [DiffLine],
  ) -> [ClosedRange<Int>] {
    let ranges = spans.filter { $0.side == side }.map(\.lines)
    guard let last = lines.last(where: { $0.number(on: side) != nil })?.number(on: side) else {
      return ranges
    }
    return ranges.map { min($0.lowerBound, last)...min($0.upperBound, last) }
  }

  private static func number(_ number: Int?, isIn ranges: [ClosedRange<Int>]) -> Bool {
    guard let number else { return false }
    let index = ranges.partitioningIndex { $0.upperBound >= number }
    return ranges.indices.contains(index) && ranges[index].lowerBound <= number
  }

  /// Ascending and apart, overlapping or touching ranges joined.
  private static func merged(_ ranges: [ClosedRange<Int>]) -> [ClosedRange<Int>] {
    var merged: [ClosedRange<Int>] = []
    for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
      if let last = merged.last, range.lowerBound <= last.upperBound + 1 {
        merged[merged.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
      } else {
        merged.append(range)
      }
    }
    return merged
  }

  func holds(_ line: DiffLine) -> Bool {
    Self.number(line.number(on: .committed), isIn: committed)
      || Self.number(line.number(on: .onDisk), isIn: onDisk)
  }
}

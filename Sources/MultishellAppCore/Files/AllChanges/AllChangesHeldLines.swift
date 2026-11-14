import MultishellCore

/// A file's held-open spans merged by side, so a build asks after each line by
/// halving them rather than walking every one: a comment holds five lines.
struct AllChangesHeldLines {
  private let committed: [ClosedRange<Int>]
  private let onDisk: [ClosedRange<Int>]

  init(_ spans: [AllChangesLineSpan]) {
    committed = Self.merged(spans.filter { $0.side == .committed }.map(\.lines))
    onDisk = Self.merged(spans.filter { $0.side == .onDisk }.map(\.lines))
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

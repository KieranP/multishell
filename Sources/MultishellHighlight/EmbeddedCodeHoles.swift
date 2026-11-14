import MultishellAppCore

/// The code inside a string's interpolation, marked `@embedded` or `@none`, cut out of
/// the spans around it; see Docs/design/files/syntax-highlighting.md.
struct EmbeddedCodeHoles {
  struct Hole {
    let pattern: Int
    let range: Range<Int>
  }

  private let holes: [Hole]

  init(_ holes: [Hole]) {
    self.holes = holes.sorted { $0.range.lowerBound < $1.range.lowerBound }
  }

  /// `span` less each hole inside it, as a span around the hole would have been under
  /// the mark; one on the hole's own range keeps it only from a later pattern.
  func pieces(of span: HighlightSpan, fromPattern pattern: Int) -> [HighlightSpan] {
    var inside: [Range<Int>] = []
    var index = holes.partitioningIndex { $0.range.lowerBound >= span.range.lowerBound }
    while index < holes.count, holes[index].range.lowerBound < span.range.upperBound {
      let hole = holes[index]
      index += 1
      let isCovered =
        hole.range.upperBound <= span.range.upperBound
        && (hole.range != span.range || hole.pattern > pattern)
      // A hole nested in one already cut is gone with it.
      guard isCovered, hole.range.lowerBound >= (inside.last?.upperBound ?? .min) else {
        continue
      }
      inside.append(hole.range)
    }
    guard !inside.isEmpty else { return [span] }
    return span.range.subtracting(inside).map { HighlightSpan(range: $0, role: span.role) }
  }
}

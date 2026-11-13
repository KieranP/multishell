import MultishellCore

/// Keeps each comment on its lines as a file tab re-reads: by the text it
/// quotes, not by row; see Docs/design/files/review-comments.md.
enum ReviewAnchoring {
  /// `rows` read under `scope`. A committed-side comment written under the other
  /// scope is left alone, that scope's committed text being another file's.
  static func reanchor(
    _ comments: [ReviewComment],
    onFile path: String,
    to rows: [DiffLine],
    readUnder scope: ChangeScope,
  ) -> [ReviewComment] {
    var sideTexts: [DiffSide: [String]] = [:]
    return comments.map { comment in
      guard comment.path == path, comment.appliesUnder(scope) else { return comment }
      let text = sideTexts[comment.side] ?? rows.text(on: comment.side)
      sideTexts[comment.side] = text
      var moved = comment
      if let found = nearestBlock(comment.quote, in: text, to: comment.lines.lowerBound) {
        moved.anchor(at: found...(found + comment.quote.count - 1))
      } else {
        moved.noteLinesChanged()
      }
      return moved
    }
  }

  /// The composer follows the lines it quotes as a comment does, and stays put
  /// where they are not found.
  static func reanchor(
    _ composer: ReviewComposer,
    to rows: [DiffLine],
    readUnder scope: ChangeScope,
  ) -> ReviewComposer {
    guard composer.appliesUnder(scope),
      let found = nearestBlock(
        composer.quote,
        in: rows.text(on: composer.side),
        to: composer.lines.lowerBound,
      )
    else { return composer }
    var moved = composer
    moved.lines = found...(found + composer.quote.count - 1)
    return moved
  }

  /// The line number where `quote` starts, the start nearest `line` where it
  /// is found more than once; the first above on a tie.
  private static func nearestBlock(_ quote: [String], in text: [String], to line: Int) -> Int? {
    guard let first = quote.first, quote.count <= text.count else { return nil }
    var nearest: Int?
    for start in 0...(text.count - quote.count) where text[start] == first {
      guard text[start..<(start + quote.count)].elementsEqual(quote) else { continue }
      let number = start + 1
      // Starts only grow, so once one past `line` is no nearer, none later is.
      if let best = nearest, abs(best - line) <= abs(number - line) { break }
      nearest = number
      if number >= line { break }
    }
    return nearest
  }
}

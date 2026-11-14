import MultishellCore

/// A review card in a file tab: a comment or the composer, in a gap under the
/// last row of its lines; see Docs/design/files/review-comments.md.
public struct ReviewCardPlacement: Identifiable, Equatable, Sendable {
  public enum Card: Equatable, Sendable {
    case comment(ReviewComment, isSelected: Bool)
    case composer(ReviewComposer)
  }

  public enum CardID: Hashable, Sendable {
    case comment(ReviewComment.ID)
    case composer(ReviewComposer.ID)
  }

  public let card: Card
  /// The rows its lines are drawn on; the gap opens under the last.
  public let rows: ClosedRange<Int>

  public var id: CardID {
    switch card {
    case .comment(let comment, _): .comment(comment.id)
    case .composer(let composer): .composer(composer.id)
    }
  }

  /// Each card's rows in `lines`, top to bottom, the composer after the comments
  /// sharing its last row. Lines past the side's end sit under its last line.
  static func placements(
    of comments: [ReviewComment],
    selected: ReviewComment.ID?,
    composer: ReviewComposer?,
    in lines: [DiffLine],
  ) -> [Self] {
    let cards =
      comments.map { Card.comment($0, isSelected: $0.id == selected) }
      + (composer.map { [Card.composer($0)] } ?? [])
    guard !cards.isEmpty else { return [] }
    // A comment whose quote went missing keeps lines the file may no longer reach.
    let wanted = cards.map { card in
      let (side, numbers) = Self.lineNumbers(of: card)
      let last = lines.last { side.shows($0.kind) }?.number(on: side) ?? numbers.upperBound
      return (side, min(numbers.lowerBound, last)...min(numbers.upperBound, last))
    }
    var needed: [DiffSide: Set<Int>] = [:]
    for (side, numbers) in wanted {
      needed[side, default: []].formUnion([numbers.lowerBound, numbers.upperBound])
    }
    // Only the numbers the cards name are kept: a 1 MiB file has tens of thousands of rows.
    var rowsByNumber: [DiffSide: [Int: Int]] = [:]
    for (row, line) in lines.enumerated() {
      for (side, numbers) in needed where side.shows(line.kind) {
        if let number = line.number(on: side), numbers.contains(number) {
          rowsByNumber[side, default: [:]][number] = row
        }
      }
    }
    return zip(cards, wanted).compactMap { card, place -> Self? in
      let (side, numbers) = place
      guard let first = rowsByNumber[side]?[numbers.lowerBound],
        let last = rowsByNumber[side]?[numbers.upperBound]
      else { return nil }
      return Self(card: card, rows: first...max(first, last))
    }
    .enumerated()
    .sorted { left, right in
      left.element.rows.upperBound != right.element.rows.upperBound
        ? left.element.rows.upperBound < right.element.rows.upperBound
        : left.offset < right.offset
    }
    .map(\.element)
  }

  private static func lineNumbers(of card: Card) -> (DiffSide, ClosedRange<Int>) {
    switch card {
    case .comment(let comment, _): (comment.side, comment.lines)
    case .composer(let composer): (composer.side, composer.lines)
    }
  }

  /// The same card on other rows: the All changes tab's, placed by a file's rows.
  func moved(to rows: ClosedRange<Int>) -> Self {
    Self(card: card, rows: rows)
  }

  /// The card a reveal asks for, or the composer editing that comment in its place.
  public func stands(for card: CardID) -> Bool {
    if id == card { return true }
    guard case .comment(let commentID) = card, case .composer(let composer) = self.card else {
      return false
    }
    return composer.editing == commentID
  }
}

import Foundation
import MultishellCore

/// A comment being written or edited in a file or All changes tab, under the
/// lines it is on. Each opening is a new one, so its card's field starts from
/// its own draft.
public struct ReviewComposer: Identifiable, Equatable, Sendable {
  public let id = UUID()
  /// The file its lines are in, which the All changes tab holds several of.
  let path: String
  let side: DiffSide
  /// Moved as a read moves the comments, so the card stays under the lines it quotes.
  var lines: ClosedRange<Int>
  /// The lines' text as the tab read them when it opened, which the comment keeps.
  let quote: [String]
  let scope: ChangeScope
  /// The comment Edit turned back into the composer, `nil` for a new one.
  let editing: ReviewComment.ID?

  /// "Comment on lines 806–810".
  public var label: String {
    let first = lines.lowerBound
    let last = lines.upperBound
    switch (side, first == last) {
    case (.onDisk, true): return t("review.composer-line", first)
    case (.onDisk, false): return t("review.composer-lines", first, last)
    case (.committed, true): return t("review.composer-removed-line", first)
    case (.committed, false): return t("review.composer-removed-lines", first, last)
    }
  }

  public var commitTitle: String {
    editing == nil ? t("review.add") : t("review.save")
  }

  /// As a comment's: the committed side only under the scope it was opened in.
  func appliesUnder(_ scope: ChangeScope) -> Bool {
    side.isRead(under: scope, writtenUnder: self.scope)
  }
}

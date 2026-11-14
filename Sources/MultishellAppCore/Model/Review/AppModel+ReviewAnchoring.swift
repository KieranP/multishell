import MultishellCore

extension AppModel {
  /// After each read of a file tab's text, the comments on that file follow
  /// their quoted lines; a gone file's keep the lines they were written on.
  func reanchorReviewComments(
    onFile path: String,
    in worktreeID: Worktree.ID,
    to rows: [DiffLine],
    readUnder scope: ChangeScope,
  ) {
    let comments = reviewComments(in: worktreeID)
    guard comments.contains(where: { $0.path == path }) else { return }
    let moved = ReviewAnchoring.reanchor(comments, onFile: path, to: rows, readUnder: scope)
    guard moved != comments else { return }
    setReviewComments(moved, of: worktreeID)
  }

  /// The open composer follows its lines too, or its card would sit under other
  /// code; only `path`'s, an All changes tab reading each file in turn.
  func reanchorReviewComposer(
    in tabID: ReviewTabID,
    onFile path: String,
    to rows: [DiffLine],
    readUnder scope: ChangeScope,
  ) {
    guard let composer = reviewComposers[tabID], composer.path == path else { return }
    setIfChanged(
      \.reviewComposers[tabID],
      ReviewAnchoring.reanchor(composer, to: rows, readUnder: scope),
    )
  }
}

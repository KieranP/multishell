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
    reanchorReviewComments(onFiles: [path: rows], in: worktreeID, readUnder: scope)
  }

  /// Every file's at once and set once: each set saves the comments and can
  /// search the All changes tab again.
  func reanchorReviewComments(
    onFiles rowsByPath: [String: [DiffLine]],
    in worktreeID: Worktree.ID,
    readUnder scope: ChangeScope,
  ) {
    let comments = reviewComments(in: worktreeID)
    var moved = comments
    for path in Set(comments.map(\.path)) {
      guard let rows = rowsByPath[path] else { continue }
      moved = ReviewAnchoring.reanchor(moved, onFile: path, to: rows, readUnder: scope)
    }
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

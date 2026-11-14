import MultishellCore

/// What a tab's review cards show on one side under its scope: its composer, and
/// the comments by file, less the one the composer edits.
struct ReviewCardSources {
  let composer: ReviewComposer?
  let commentsByPath: [String: [ReviewComment]]

  func composer(onFile path: String) -> ReviewComposer? {
    composer?.path == path ? composer : nil
  }

  func comments(onFile path: String) -> [ReviewComment] {
    commentsByPath[path] ?? []
  }
}

extension MergePath.End {
  /// The pull request glyph the path ends on: the merge to come, green only
  /// where it merges now, or what became of it.
  public var mark: PullRequestMark {
    switch self {
    case .closed: PullRequestMark(shape: .closed, tone: .secondary)
    case .merged: PullRequestMark(shape: .merged, tone: .merged)
    case .offers(.merge): PullRequestMark(shape: .open, tone: .readyToMerge)

    case .offers(.cancelAutoMerge), .offers(.mergeWhenReady), .taken:
      PullRequestMark(shape: .open, tone: .secondary)

    case .waits: PullRequestMark(shape: .open, tone: .tertiary)
    }
  }
}

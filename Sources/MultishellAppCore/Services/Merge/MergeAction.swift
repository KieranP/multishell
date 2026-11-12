/// What the pull request page's merge path offers toward merging.
public enum MergeAction: Equatable, Sendable {
  case cancelAutoMerge
  case merge
  /// Only required checks still running hold it back: auto-merge.
  case mergeWhenReady
}

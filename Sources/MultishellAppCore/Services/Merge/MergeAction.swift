/// What the pull request page's merge path offers toward merging.
public enum MergeAction: Equatable, Sendable {
  case cancelAutoMerge
  case merge
  /// Only machines hold it back, running required checks or an unchecked conflict: auto-merge.
  case mergeWhenReady
}

import MultishellCore
import MultishellGitKit

extension WorktreeMergeState {
  /// The row's tooltip. "Safe to remove" only where the evidence is proof;
  /// the badge is not drawn at all where there is work to lose.
  public var tooltip: String {
    guard case .merged = self else { return "" }
    return isCertain ? t("merged.safe-to-remove", summary) : summary
  }

  /// Whether the row draws the badge, given `git status`. Uncommitted work, or
  /// commits its upstream lacks, hide it; see Docs/design/merged-branch.md.
  func showsBadge(with status: WorktreeStatus?) -> Bool {
    guard case .merged = self else { return false }
    guard let status else { return true }
    return !status.isDirty && (status.upstream == nil || status.ahead == 0)
  }
}

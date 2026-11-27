import MultishellCore
import MultishellGitKit

extension WorktreeStatus {
  /// "Rebasing · 2 conflicts" while a merge or rebase is stopped here, which the
  /// row shows in place of its line counts; `nil` otherwise.
  var unfinishedUpdateText: String? {
    unfinishedUpdate.map { $0.unfinishedText(conflicts: conflicted) }
  }

  /// What that text's tooltip says to do: send the conflicts or abort, or with
  /// nothing unmerged, continue or abort.
  var unfinishedUpdateHelp: String? {
    guard let unfinishedUpdate else { return nil }
    guard conflicted == 0 else { return t("base-update.unfinished-conflicts-help") }
    return t("base-update.unfinished-help", unfinishedUpdate.continueCommand)
  }
}

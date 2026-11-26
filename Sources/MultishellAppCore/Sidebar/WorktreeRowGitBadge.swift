import MultishellGitKit

/// What a worktree row shows of its git state, and says aloud: a stopped merge
/// or rebase in place of the counts, the counts, or nothing for a clean row in sync.
public enum WorktreeRowGitBadge: Equatable, Sendable {
  case counts(WorktreeStatus)
  case unfinishedUpdate(text: String, help: String)

  /// The words VoiceOver reads in the badge's place on the row's label.
  var summary: String {
    switch self {
    case .counts(let status): status.summary
    case .unfinishedUpdate(let text, _): text
    }
  }

  public init?(_ status: WorktreeStatus?) {
    if let text = status?.unfinishedUpdateText, let help = status?.unfinishedUpdateHelp {
      self = .unfinishedUpdate(text: text, help: help)
    } else if let badged = WorktreeStatus.badged(status) {
      self = .counts(badged)
    } else {
      return nil
    }
  }

  /// A row too crowded for the badge keeps a stop as the warning glyph the other
  /// alerts use, saying these words; counts it drops.
  public func crowdedAlert(in fit: WorktreeRowBadgeFit) -> String? {
    guard !fit.showsGitState, case .unfinishedUpdate(let text, _) = self else { return nil }
    return text
  }
}

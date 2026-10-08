import MultishellCore
import MultishellGitKit

extension WorktreeStatus {
  /// The status a row or card draws as its git badge, `nil` where there is
  /// none: not read yet, or clean and in sync.
  public static func badged(_ status: WorktreeStatus?) -> WorktreeStatus? {
    guard let status, !status.isCleanAndInSync else { return nil }
    return status
  }
}

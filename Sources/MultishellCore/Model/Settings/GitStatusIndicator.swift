/// What the sidebar's and the board's git badge counts. A raw value is
/// written to the state file, so add cases but never rename one.
public enum GitStatusIndicator: String, Codable, Hashable, Sendable, CaseIterable {
  /// Everything the working tree holds, a new file's whole contents with it.
  /// First, being the default and what most people want.
  case stagedAndUnstaged
  /// Only what `git diff --cached` shows: the lines already staged.
  case stagedOnly

  /// What people work in most of the time is unstaged, so a badge counting
  /// the index alone would read zero through most of a change.
  public static let `default` = GitStatusIndicator.stagedAndUnstaged

  public var displayName: String {
    switch self {
    case .stagedAndUnstaged: t("indicator.staged-unstaged")
    case .stagedOnly: t("indicator.staged")
    }
  }
}

/// How the badge's line counts match old lines to new, passed so a user's own
/// `diff.algorithm` cannot move them. Raw values are git's names: never rename.
public enum DiffAlgorithm: String, Codable, Hashable, Sendable, CaseIterable {
  case histogram
  case minimal
  case myers
  case patience

  /// The user's choice. git's own default is Myers, so a plain `git diff` can
  /// count the same edit differently.
  public static let `default` = Self.histogram

  public var displayName: String {
    switch self {
    case .histogram: t("diff-algorithm.histogram")
    case .minimal: t("diff-algorithm.minimal")
    case .myers: t("diff-algorithm.myers")
    case .patience: t("diff-algorithm.patience")
    }
  }
}

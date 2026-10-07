/// How git spells a branch as a full refname, and back.
enum RefName {
  /// The ref a clone records as the remote's default branch.
  static let originHead = "refs/remotes/origin/HEAD"

  static let localPrefix = "refs/heads/"
  static let remotePrefix = "refs/remotes/"

  /// Full refname: a bare name reaches a tag of that name first, and git's
  /// ambiguity warning goes to stderr, which `runner.output` throws away.
  static func local(_ branch: String) -> String { localPrefix + branch }

  /// `origin/main` as a full refname, for the same reason as `local`.
  static func remote(_ branch: String) -> String { remotePrefix + branch }

  /// `refs/heads/feat` as `feat`, and any other name as it is.
  static func shortLocal(_ ref: String) -> String {
    ref.hasPrefix(localPrefix) ? String(ref.dropFirst(localPrefix.count)) : ref
  }
}

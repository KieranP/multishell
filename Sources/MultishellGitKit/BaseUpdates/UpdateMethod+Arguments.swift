import MultishellCore

extension UpdateMethod {
  var abortArguments: [String] { [rawValue, "--abort"] }

  /// git's own wording with the short name: handed the full refname that keeps
  /// a tag of the same name out, git writes `'refs/remotes/origin/main'`.
  private static func mergeMessage(of base: DefaultBranch, into branch: String) -> String {
    let kind = base.isRemoteTracking ? "remote-tracking branch" : "branch"
    return "Merge \(kind) '\(base.shortName)' into \(branch)"
  }

  /// Never autostashed: the stash stack is every worktree's. `--ff` stands over a
  /// `merge.ff=only`; `--no-update-refs` leaves stacked branches, which no one was asked about.
  func arguments(onto base: DefaultBranch, from branch: String) -> [String] {
    switch self {
    case .merge:
      [
        "merge", "--no-edit", "--ff", "--no-autostash",
        "-m", Self.mergeMessage(of: base, into: branch), base.fullName,
      ]

    case .rebase: ["rebase", "--no-autostash", "--no-update-refs", base.fullName]
    }
  }
}

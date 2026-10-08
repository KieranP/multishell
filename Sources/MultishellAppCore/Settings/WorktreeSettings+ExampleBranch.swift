import MultishellCore

extension WorktreeSettings {
  /// A name a user might type, in the reader's language, so the caption's
  /// sentence and the branch it shows agree.
  static var exampleBranchName: String { t("worktrees.example-branch-name") }

  /// One branch name with the prefix put on, so a caption shows what it does.
  var exampleBranch: String { qualifiedBranch(Self.exampleBranchName) }

  /// What a typed name becomes, `nil` with no prefix to show.
  public var prefixExampleCaption: String? {
    guard !branchPrefix.isEmpty else { return nil }
    return t("worktrees.prefix-example", Self.exampleBranchName, exampleBranch)
  }
}

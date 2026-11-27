import MultishellCore

extension PendingBranchPublish {
  public var title: String {
    t("publish.title", branch, t("publish.remote-branch", remote, remoteBranch))
  }

  /// Why it asks: the pull request is made from what the remote has.
  public var message: String {
    if remoteHasBranch { return t("publish.message-untracked-branch", remote, remoteBranch) }
    guard let unpushedCommits else { return t("publish.message-new-branch", remote, remoteBranch) }
    return t("publish.message-unpushed", remote, t("count.unpushed-commits", unpushedCommits))
  }

  public var confirmLabel: String { t("publish.push") }
}

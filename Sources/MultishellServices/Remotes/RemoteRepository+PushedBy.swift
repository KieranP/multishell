import MultishellGitKit

extension RemoteRepository {
  /// Where a branch on `remote` lives: where the remote pushes, which a
  /// triangular set-up sets apart from where it fetches.
  public init?(pushedBy remote: GitRemote) {
    self.init(remoteURL: remote.effectivePushURL)
  }
}

import MultishellGitKit
import MultishellServices

extension RemoteRepository {
  /// Where a branch on `remote` lives: where the remote pushes, which a
  /// triangular set-up sets apart from where it fetches.
  init?(pushedTo remote: String, among remotes: [GitRemote]) {
    guard let found = remotes.first(where: { $0.name == remote }) else { return nil }
    self.init(remoteURL: found.pushURL ?? found.url)
  }
}

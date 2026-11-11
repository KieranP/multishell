import MultishellGitKit
import MultishellServices

/// Where a remote's pushes land: the repository its URL names and, where the
/// host renamed or moved it since, its name today. See services/branch-matching.md.
enum PushedRepositories {
  /// None for a remote not listed, or one whose URL names no repository.
  static func of(
    remote: String,
    among remotes: [GitRemote],
    currentRepositories: [String: RemoteRepository],
  ) -> [RemoteRepository] {
    guard let found = remotes.first(where: { $0.name == remote }) else { return [] }
    let named = RemoteRepository(pushedBy: found)
    let current = currentRepositories[found.effectivePushURL]
    guard let current, named.map(current.isSame(as:)) != true else {
      return [named].compactMap(\.self)
    }
    return [named, current].compactMap(\.self)
  }
}

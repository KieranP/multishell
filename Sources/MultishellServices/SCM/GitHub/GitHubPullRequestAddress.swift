import Foundation

/// Where a pull request lives, read from its page's URL: `gh api` fills
/// `{owner}` and `{repo}` apart from `gh pr`, which honours `gh repo set-default`.
struct GitHubPullRequestAddress: Equatable {
  let host: String
  let repository: RemoteRepository

  init?(_ url: URL) {
    let parts = url.pathComponents.filter { $0 != "/" }
    guard let host = url.host(), parts.count >= 4, parts[2] == "pull" else { return nil }
    self.host = host
    repository = RemoteRepository(owner: parts[0], name: parts[1])
  }
}

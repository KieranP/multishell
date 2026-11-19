import Foundation

/// Where a pull request lives, read from its page's URL: `gh api` fills
/// `{owner}` and `{repo}` apart from `gh pr`, which honours `gh repo set-default`.
struct GitHubPullRequestAddress: Equatable {
  let host: String
  let repository: RemoteRepository

  init?(_ url: URL) {
    guard let path = GitHubRepositoryPath(url), path.pageParts.count >= 2,
      path.pageParts[0] == "pull"
    else { return nil }
    host = path.host
    repository = path.repository
  }
}

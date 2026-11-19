import Foundation

/// A GitHub page's host and repository, `https://<host>/<owner>/<repo>/…`, and
/// the path under the repository that says which page it is.
struct GitHubRepositoryPath: Equatable {
  let host: String
  let repository: RemoteRepository
  let pageParts: [String]

  init?(_ url: URL) {
    let parts = url.pathComponents.filter { $0 != "/" }
    guard let host = url.host(), parts.count >= 2 else { return nil }
    self.host = host
    repository = RemoteRepository(owner: parts[0], name: parts[1])
    pageParts = Array(parts.dropFirst(2))
  }
}

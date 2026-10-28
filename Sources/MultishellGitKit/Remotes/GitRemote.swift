/// A remote as `git remote -v` lists it for fetching.
public struct GitRemote: Hashable, Sendable {
  public let name: String
  /// As configured, `git@github.com:owner/repo.git` or an https or ssh URL.
  public let url: String
  /// Where it pushes, where git was told another place than it fetches from.
  public let pushURL: String?

  init(name: String, url: String, pushURL: String? = nil) {
    self.name = name
    self.url = url
    self.pushURL = pushURL
  }
}

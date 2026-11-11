/// A remote as `git remote -v` lists it for fetching.
public struct GitRemote: Hashable, Sendable {
  public let name: String
  /// As configured, `git@github.com:owner/repo.git` or an https or ssh URL.
  public let url: String
  /// Where it pushes, where git was told another place than it fetches from.
  let pushURL: String?

  /// Where its pushes land: `pushURL`, or the fetch URL where none was set.
  public var effectivePushURL: String { pushURL ?? url }

  init(name: String, url: String, pushURL: String? = nil) {
    self.name = name
    self.url = url
    self.pushURL = pushURL
  }
}

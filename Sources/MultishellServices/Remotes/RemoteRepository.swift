import Foundation

/// A hosted repository as its owner and name, which a remote's URL and a
/// pull request's head both say. Compared without case, as hosts do.
public struct RemoteRepository: Hashable, Sendable {
  /// `KieranP`, or a group path such as `team/sub` on hosts that nest them.
  let owner: String
  let name: String

  /// `owner/name` folded, as hosts compare them: what makes two the same.
  var identity: String { "\(owner)/\(name)".lowercased() }

  init(owner: String, name: String) {
    self.owner = owner
    self.name = name
  }

  /// `git@host:owner/name.git`, `ssh://…/owner/name` or `https://host/owner/name`;
  /// `nil` for a path or fewer than two components after the host.
  public init?(remoteURL: String) {
    let path: Substring
    // A file URL is a path written as a URL, on no host.
    if remoteURL.lowercased().hasPrefix("file://") { return nil }
    if let scheme = remoteURL.range(of: "://") {
      let afterScheme = remoteURL[scheme.upperBound...]
      guard let slash = afterScheme.firstIndex(of: "/") else { return nil }
      path = afterScheme[afterScheme.index(after: slash)...]
    } else if let colon = remoteURL.firstIndex(of: ":"), !remoteURL.hasPrefix("/") {
      // scp-like syntax; a colon after the first slash is a local path's.
      guard !remoteURL[..<colon].contains("/") else { return nil }
      path = remoteURL[remoteURL.index(after: colon)...]
    } else {
      return nil
    }
    var components = path.split(separator: "/").map(String.init)
    guard components.count >= 2, var name = components.popLast() else { return nil }
    if name.hasSuffix(".git") { name.removeLast(4) }
    guard !name.isEmpty else { return nil }
    self.init(owner: components.joined(separator: "/"), name: name)
  }

  public func isSame(as other: Self) -> Bool {
    identity == other.identity
  }
}

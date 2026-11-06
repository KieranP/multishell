/// A worktree's name cut at its last `/`, so a cramped row drops the prefix
/// branches share before the leaf that tells them apart; see worktrees/sidebar.md.
public struct BranchNameParts: Equatable, Sendable {
  /// Up to and including the last `/`, empty where there is none.
  public let prefix: String
  public let leaf: String

  public init(_ name: String) {
    guard let slash = name.lastIndex(of: "/") else {
      prefix = ""
      leaf = name
      return
    }
    prefix = String(name[...slash])
    leaf = String(name[name.index(after: slash)...])
  }
}

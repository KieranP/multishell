/// A worktree's name cut at its last `/`, so a cramped row drops the prefix
/// branches share before the leaf that tells them apart; see worktrees/sidebar.md.
public struct BranchNameParts: Equatable, Sendable {
  /// Up to and including the last `/`, empty where there is none.
  public let prefix: String
  public let leaf: String

  public init(_ name: String) {
    // By scalar: a leaf starting with a combining mark joins the slash into one Character.
    guard let slash = name.unicodeScalars.lastIndex(of: "/") else {
      prefix = ""
      leaf = name
      return
    }
    let leafStart = name.unicodeScalars.index(after: slash)
    prefix = String(name[..<leafStart])
    leaf = String(name[leafStart...])
  }
}

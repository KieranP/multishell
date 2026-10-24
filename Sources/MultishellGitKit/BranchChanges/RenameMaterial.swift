/// What Auto Rename tells the agent about a branch: its commits and staged
/// changes since it left the project's base branch.
public struct RenameMaterial: Hashable, Sendable {
  /// The branch `HEAD` is on as the read found it, `nil` when detached: the
  /// sidebar's listing may not have seen a checkout yet.
  public let branch: String?
  /// Newest first.
  public let subjects: [String]
  public let diffstat: String
  public let diff: String
  /// The diff stops short of the whole, the rest left out so a large branch
  /// fits what a model takes.
  public let isDiffCut: Bool

  /// Nothing committed or staged: no name can come of it.
  public var isEmpty: Bool { subjects.isEmpty && diffstat.isEmpty }
}

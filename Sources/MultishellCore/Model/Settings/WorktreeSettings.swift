import Foundation

/// Where worktrees go and how their branches are named, global or a project's in
/// effect. Path and branch decisions read this, never `ProjectSettings` directly.
public struct WorktreeSettings: Codable, Hashable, Sendable {
  static let defaultWorktreeDirectory = "../{project}-worktrees"

  /// Directory that will hold a project's worktrees. Absolute, or relative
  /// to the repository root. `~` and `{project}` are expanded.
  public var worktreeDirectory: String

  /// Prepended to branch names typed in the new-worktree sheet.
  public var branchPrefix: String

  init(
    worktreeDirectory: String = Self.defaultWorktreeDirectory,
    branchPrefix: String = "",
  ) {
    self.worktreeDirectory = worktreeDirectory
    self.branchPrefix = branchPrefix
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    worktreeDirectory = try container.decode(
      String.self,
      forKey: .worktreeDirectory,
      or: Self.defaultWorktreeDirectory,
    )
    branchPrefix = try container.decode(String.self, forKey: .branchPrefix, or: "")
  }
}

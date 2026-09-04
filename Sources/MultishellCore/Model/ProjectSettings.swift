import Foundation

/// Per-project preferences, edited in the project's settings panel.
///
/// The worktree fields are overrides: `nil` means "use the app-wide value in
/// `Workspace.worktreeDefaults`". Hooks are per-project only.
public struct ProjectSettings: Codable, Hashable, Sendable {
  public var worktreeDirectory: String?
  public var branchPrefix: String?

  /// Command lines run through the platform shell after a worktree is
  /// created or removed. Empty means no hook.
  public var postCreateHook: String
  public var postDeleteHook: String

  /// Ask before `git worktree remove`. Off is for people who remove
  /// worktrees all day and trust themselves; the default protects everyone
  /// else.
  public var confirmsWorktreeRemoval: Bool

  public init(
    worktreeDirectory: String? = nil,
    branchPrefix: String? = nil,
    postCreateHook: String = "",
    postDeleteHook: String = "",
    confirmsWorktreeRemoval: Bool = true
  ) {
    self.worktreeDirectory = worktreeDirectory
    self.branchPrefix = branchPrefix
    self.postCreateHook = postCreateHook
    self.postDeleteHook = postDeleteHook
    self.confirmsWorktreeRemoval = confirmsWorktreeRemoval
  }

  /// An empty string on disk reads as "no override". State from before
  /// overrides existed stored "" for "no prefix", and it should keep
  /// following the global once one is set. Opting out of a global value is
  /// a whitespace-only string, which `effective` trims to empty.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    worktreeDirectory = Self.override(
      try c.decodeIfPresent(String.self, forKey: .worktreeDirectory))
    branchPrefix = Self.override(try c.decodeIfPresent(String.self, forKey: .branchPrefix))
    postCreateHook = try c.decodeIfPresent(String.self, forKey: .postCreateHook) ?? ""
    postDeleteHook = try c.decodeIfPresent(String.self, forKey: .postDeleteHook) ?? ""
    confirmsWorktreeRemoval =
      try c.decodeIfPresent(Bool.self, forKey: .confirmsWorktreeRemoval) ?? true
  }

  private static func override(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }

  /// The project's value where it has one, the default otherwise.
  public func effective(defaults: WorktreeSettings) -> WorktreeSettings {
    WorktreeSettings(
      worktreeDirectory: worktreeDirectory?.trimmingCharacters(in: .whitespaces)
        ?? defaults.worktreeDirectory,
      branchPrefix: branchPrefix?.trimmingCharacters(in: .whitespaces) ?? defaults.branchPrefix
    )
  }
}

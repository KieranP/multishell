import Foundation

/// Per-project preferences, edited in the project's settings panel.
///
/// The worktree fields are overrides: `nil` means "use the app-wide value in
/// `Workspace.worktreeDefaults`". Hooks are per-project only.
public struct ProjectSettings: Codable, Hashable, Sendable {
  public var worktreeDirectory: String?
  public var branchPrefix: String?

  /// Scripts run through the user's login shell around `git worktree add`
  /// and `git worktree remove`. Empty means no hook. A pre hook that fails
  /// stops the operation; a post hook that fails is reported after it.
  public var preCreateHook: String
  public var postCreateHook: String
  public var preDeleteHook: String
  public var postDeleteHook: String

  /// Ask before `git worktree remove`. Off is for people who remove
  /// worktrees all day and trust themselves; the default protects everyone
  /// else.
  public var confirmsWorktreeRemoval: Bool

  /// Agent override by catalogue id. `nil` follows the global choice;
  /// `AgentCatalogue.noneID` opts this project out of it.
  public var preferredAgentID: String?
  /// Whether new tabs here start the agent. `nil` follows the global.
  public var autoStartAgent: Bool?

  /// Shell override by path. `nil` follows the global choice;
  /// `ShellCatalogue.loginShellID` means `$SHELL` here whatever it says.
  public var defaultShell: String?

  /// The sidebar glyph: an emoji, or an SF Symbol name from
  /// `ProjectIcon.symbols`. `nil` draws the folder.
  public var iconGlyph: String?
  /// A slot in the theme's sixteen ANSI colours, or `nil` for the chrome's
  /// own text colour. Applies to symbols and the folder; emoji keep their
  /// own colours.
  public var iconTint: Int?

  public init(
    worktreeDirectory: String? = nil,
    branchPrefix: String? = nil,
    preCreateHook: String = "",
    postCreateHook: String = "",
    preDeleteHook: String = "",
    postDeleteHook: String = "",
    confirmsWorktreeRemoval: Bool = true,
    preferredAgentID: String? = nil,
    autoStartAgent: Bool? = nil,
    defaultShell: String? = nil,
    iconGlyph: String? = nil,
    iconTint: Int? = nil
  ) {
    self.worktreeDirectory = worktreeDirectory
    self.branchPrefix = branchPrefix
    self.preCreateHook = preCreateHook
    self.postCreateHook = postCreateHook
    self.preDeleteHook = preDeleteHook
    self.postDeleteHook = postDeleteHook
    self.confirmsWorktreeRemoval = confirmsWorktreeRemoval
    self.preferredAgentID = preferredAgentID
    self.autoStartAgent = autoStartAgent
    self.defaultShell = defaultShell
    self.iconGlyph = iconGlyph
    self.iconTint = ProjectIcon.validTint(iconTint)
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
    preCreateHook = try c.decodeIfPresent(String.self, forKey: .preCreateHook) ?? ""
    postCreateHook = try c.decodeIfPresent(String.self, forKey: .postCreateHook) ?? ""
    preDeleteHook = try c.decodeIfPresent(String.self, forKey: .preDeleteHook) ?? ""
    postDeleteHook = try c.decodeIfPresent(String.self, forKey: .postDeleteHook) ?? ""
    confirmsWorktreeRemoval =
      try c.decodeIfPresent(Bool.self, forKey: .confirmsWorktreeRemoval) ?? true
    preferredAgentID = Self.override(try c.decodeIfPresent(String.self, forKey: .preferredAgentID))
    autoStartAgent = try c.decodeIfPresent(Bool.self, forKey: .autoStartAgent)
    defaultShell = Self.override(try c.decodeIfPresent(String.self, forKey: .defaultShell))
    iconGlyph = Self.override(try c.decodeIfPresent(String.self, forKey: .iconGlyph))
    // `try?`: a tint that is not a number costs the tint, not the file.
    iconTint = ProjectIcon.validTint(try? c.decodeIfPresent(Int.self, forKey: .iconTint))
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

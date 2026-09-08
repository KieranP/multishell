import Foundation

/// Per-project preferences, edited in the project's settings panel.
///
/// The worktree fields are overrides: `nil` means "use the app-wide value in
/// `Workspace.worktreeDefaults`". Hooks are per-project only.
public struct ProjectSettings: Codable, Hashable, Sendable {
  public var worktreeDirectory: String?
  public var branchPrefix: String?
  /// The branch this project's work is merged into, for the sidebar's
  /// merged badge. `nil` detects it: `origin/HEAD`, then `origin/main`,
  /// `origin/master`, `main`, `master`. A name typed here is looked for on
  /// `origin` before it is looked for locally.
  public var defaultBranch: String?

  /// Scripts run through the user's login shell around `git worktree add`
  /// and `git worktree remove`. Empty means no hook. A pre hook that fails
  /// stops the operation; a post hook that fails is reported after it.
  public var preCreateHook: String
  public var postCreateHook: String
  public var preDeleteHook: String
  public var postDeleteHook: String

  /// Agent override by catalogue id. `nil` follows the global choice;
  /// `AgentCatalogue.noneID` opts this project out of it.
  public var preferredAgentID: String?
  /// Whether new tabs here start the agent. `nil` follows the global.
  public var autoStartAgent: Bool?
  /// Whether the tab a worktree created here opens starts the agent. `nil`
  /// follows the global.
  public var autoStartAgentOnCreate: Bool?

  /// Whether a worktree here opens a terminal when it is turned to. `nil`
  /// follows the global.
  public var opensTerminalOnSelect: Bool?

  /// The order this project's worktree rows are listed in. `nil` follows
  /// the global.
  public var worktreeSortOrder: WorktreeSortOrder?
  /// Whether this project's busy worktrees are listed above the rest.
  /// `nil` follows the global.
  public var showsActiveWorktreesFirst: Bool?

  /// Whether a worktree created here opens a terminal once the create, and
  /// any post-create hook, is done. `nil` follows the global.
  public var opensTerminalOnCreate: Bool?

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

  /// What the user said about the hooks in the repository's
  /// `.multishell.json`, and which text they said it about. `nil` until
  /// asked; a file whose hooks have since changed asks again.
  public var sharedHooks: SharedHooksDecision?

  public init(
    worktreeDirectory: String? = nil,
    branchPrefix: String? = nil,
    defaultBranch: String? = nil,
    preCreateHook: String = "",
    postCreateHook: String = "",
    preDeleteHook: String = "",
    postDeleteHook: String = "",
    preferredAgentID: String? = nil,
    autoStartAgent: Bool? = nil,
    autoStartAgentOnCreate: Bool? = nil,
    opensTerminalOnSelect: Bool? = nil,
    opensTerminalOnCreate: Bool? = nil,
    worktreeSortOrder: WorktreeSortOrder? = nil,
    showsActiveWorktreesFirst: Bool? = nil,
    defaultShell: String? = nil,
    iconGlyph: String? = nil,
    iconTint: Int? = nil,
    sharedHooks: SharedHooksDecision? = nil
  ) {
    self.worktreeDirectory = worktreeDirectory
    self.branchPrefix = branchPrefix
    self.defaultBranch = defaultBranch
    self.preCreateHook = preCreateHook
    self.postCreateHook = postCreateHook
    self.preDeleteHook = preDeleteHook
    self.postDeleteHook = postDeleteHook
    self.preferredAgentID = preferredAgentID
    self.autoStartAgent = autoStartAgent
    self.autoStartAgentOnCreate = autoStartAgentOnCreate
    self.opensTerminalOnSelect = opensTerminalOnSelect
    self.opensTerminalOnCreate = opensTerminalOnCreate
    self.worktreeSortOrder = worktreeSortOrder
    self.showsActiveWorktreesFirst = showsActiveWorktreesFirst
    self.defaultShell = defaultShell
    self.iconGlyph = iconGlyph
    self.iconTint = ProjectIcon.validTint(iconTint)
    self.sharedHooks = sharedHooks
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
    defaultBranch = Self.override(try c.decodeIfPresent(String.self, forKey: .defaultBranch))
    preCreateHook = try c.decodeIfPresent(String.self, forKey: .preCreateHook) ?? ""
    postCreateHook = try c.decodeIfPresent(String.self, forKey: .postCreateHook) ?? ""
    preDeleteHook = try c.decodeIfPresent(String.self, forKey: .preDeleteHook) ?? ""
    postDeleteHook = try c.decodeIfPresent(String.self, forKey: .postDeleteHook) ?? ""
    preferredAgentID = Self.override(try c.decodeIfPresent(String.self, forKey: .preferredAgentID))
    autoStartAgent = try c.decodeIfPresent(Bool.self, forKey: .autoStartAgent)
    // Absent is "follow the global", not "what `autoStartAgent` says": a
    // nil override is written as an absent key, so seeding it from the
    // other one would turn the global back into an override on every load.
    autoStartAgentOnCreate = try c.decodeIfPresent(Bool.self, forKey: .autoStartAgentOnCreate)
    opensTerminalOnSelect = try c.decodeIfPresent(Bool.self, forKey: .opensTerminalOnSelect)
    opensTerminalOnCreate = try c.decodeIfPresent(Bool.self, forKey: .opensTerminalOnCreate)
    // `try?`: an order a newer build named is not an override this one can
    // honour, and following the global beats losing the project.
    worktreeSortOrder =
      (try? c.decodeIfPresent(WorktreeSortOrder.self, forKey: .worktreeSortOrder)) ?? nil
    showsActiveWorktreesFirst = try c.decodeIfPresent(
      Bool.self, forKey: .showsActiveWorktreesFirst)
    defaultShell = Self.override(try c.decodeIfPresent(String.self, forKey: .defaultShell))
    iconGlyph = Self.override(try c.decodeIfPresent(String.self, forKey: .iconGlyph))
    // `try?`: a tint that is not a number costs the tint, not the file.
    iconTint = ProjectIcon.validTint(try? c.decodeIfPresent(Int.self, forKey: .iconTint))
    sharedHooks = (try? c.decodeIfPresent(SharedHooksDecision.self, forKey: .sharedHooks)) ?? nil
  }

  private static func override(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }

  /// Whether the hooks in `shared` are the ones the user trusted. A file
  /// whose hooks have changed since is not trusted until asked again.
  public func trustsHooks(of shared: SharedProjectSettings) -> Bool {
    guard let text = shared.hooksText, let decision = sharedHooks else { return false }
    return decision.trusted && decision.hooks == text
  }

  /// Whether `shared` has hooks the user has not yet been asked about.
  public func needsHookDecision(for shared: SharedProjectSettings) -> Bool {
    guard let text = shared.hooksText else { return false }
    return sharedHooks?.hooks != text
  }

  /// These settings with the repository's own filling the gaps: a path or
  /// prefix the user left following the global, what a worktree here opens
  /// where they said nothing, the order its rows come in, an icon they did
  /// not set, and a hook they left blank, the last only once its text is
  /// trusted. A whitespace-only
  /// hook is the user's "none" and stays.
  public func layered(over shared: SharedProjectSettings?) -> ProjectSettings {
    guard let shared else { return self }
    var result = self
    result.worktreeDirectory = worktreeDirectory ?? shared.worktreeDirectory
    result.branchPrefix = branchPrefix ?? shared.branchPrefix
    result.defaultBranch = defaultBranch ?? shared.defaultBranch
    result.autoStartAgent = autoStartAgent ?? shared.autoStartAgent
    result.autoStartAgentOnCreate = autoStartAgentOnCreate ?? shared.autoStartAgentOnCreate
    result.opensTerminalOnSelect = opensTerminalOnSelect ?? shared.opensTerminalOnSelect
    result.opensTerminalOnCreate = opensTerminalOnCreate ?? shared.opensTerminalOnCreate
    result.worktreeSortOrder = worktreeSortOrder ?? shared.worktreeSortOrder
    result.showsActiveWorktreesFirst =
      showsActiveWorktreesFirst ?? shared.showsActiveWorktreesFirst
    result.iconGlyph = iconGlyph ?? shared.iconGlyph
    result.iconTint = iconTint ?? ProjectIcon.validTint(shared.iconTint)
    if trustsHooks(of: shared) {
      result.preCreateHook = preCreateHook.isEmpty ? shared.preCreateHook ?? "" : preCreateHook
      result.postCreateHook = postCreateHook.isEmpty ? shared.postCreateHook ?? "" : postCreateHook
      result.preDeleteHook = preDeleteHook.isEmpty ? shared.preDeleteHook ?? "" : preDeleteHook
      result.postDeleteHook = postDeleteHook.isEmpty ? shared.postDeleteHook ?? "" : postDeleteHook
    }
    return result
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

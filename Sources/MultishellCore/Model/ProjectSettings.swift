import Foundation

/// Per-project preferences, edited in the project's settings panel. Worktree
/// fields are overrides, `nil` following the global; see docs/design/settings.md.
public struct ProjectSettings: Codable, Hashable, Sendable {
  public var worktreeDirectory: String?
  public var branchPrefix: String?
  /// The branch merges are measured against. `nil` detects it: `origin/HEAD`,
  /// then `origin/main`, `origin/master`, `main`, `master`.
  public var defaultBranch: String?

  /// Scripts run through the user's login shell around `git worktree add` and
  /// `remove`. Empty means no hook; see docs/design/hooks.md.
  public var preCreateHook: String
  public var postCreateHook: String
  public var preDeleteHook: String
  public var postDeleteHook: String

  /// Paths each new worktree is symlinked back to the repository's own, one
  /// per line: `node_modules`, a build cache. Blank links nothing.
  public var linkedPaths: String
  /// Paths copied from the repository into each new worktree, one per line,
  /// for what git does not carry: `.env`, a local config.
  public var copiedPaths: String

  /// Agent override by catalogue id. `nil` follows the global;
  /// `AgentCatalogue.noneID` opts this project out of it.
  public var preferredAgentID: String?
  /// Extra arguments the agent is started with here. `""` is the override to
  /// no flags at all; see docs/design/agents.md for why a repo file cannot say this.
  public var agentFlags: String?
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

  /// Shell override by path. `nil` follows the global;
  /// `ShellCatalogue.loginShellID` means `$SHELL` here whatever it says.
  public var defaultShell: String?

  /// The sidebar glyph: an SF Symbol name from `ProjectIcon.symbols`. `nil`,
  /// or any other string, draws the folder.
  public var iconGlyph: String?
  /// A slot in the theme's sixteen ANSI colours, or `nil` for the chrome's
  /// own text colour. Applies to symbols and the folder alike.
  public var iconTint: Int?

  /// One answer per `.multishell.json` the user was asked about, against the
  /// sha256 of its bytes, newest first; see docs/design/settings.md.
  public var sharedHooks: [SharedHooksDecision]

  /// How many files a project remembers an answer for.
  public static let rememberedSharedHooks = 16

  public init(
    worktreeDirectory: String? = nil,
    branchPrefix: String? = nil,
    defaultBranch: String? = nil,
    preCreateHook: String = "",
    postCreateHook: String = "",
    preDeleteHook: String = "",
    postDeleteHook: String = "",
    linkedPaths: String = "",
    copiedPaths: String = "",
    preferredAgentID: String? = nil,
    agentFlags: String? = nil,
    autoStartAgent: Bool? = nil,
    autoStartAgentOnCreate: Bool? = nil,
    opensTerminalOnSelect: Bool? = nil,
    opensTerminalOnCreate: Bool? = nil,
    worktreeSortOrder: WorktreeSortOrder? = nil,
    showsActiveWorktreesFirst: Bool? = nil,
    defaultShell: String? = nil,
    iconGlyph: String? = nil,
    iconTint: Int? = nil,
    sharedHooks: [SharedHooksDecision] = []
  ) {
    self.worktreeDirectory = worktreeDirectory
    self.branchPrefix = branchPrefix
    self.defaultBranch = defaultBranch
    self.preCreateHook = preCreateHook
    self.postCreateHook = postCreateHook
    self.preDeleteHook = preDeleteHook
    self.postDeleteHook = postDeleteHook
    self.linkedPaths = linkedPaths
    self.copiedPaths = copiedPaths
    self.preferredAgentID = preferredAgentID
    self.agentFlags = agentFlags
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

  /// `""` overrides to "none" for the four fields with no other spelling for
  /// it, and is noise elsewhere; see docs/design/settings.md.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    worktreeDirectory = try container.decodeIfPresent(String.self, forKey: .worktreeDirectory)
    branchPrefix = try container.decodeIfPresent(String.self, forKey: .branchPrefix)
    defaultBranch = try container.decodeIfPresent(String.self, forKey: .defaultBranch)
    preCreateHook = try container.decode(String.self, forKey: .preCreateHook, or: "")
    postCreateHook = try container.decode(String.self, forKey: .postCreateHook, or: "")
    preDeleteHook = try container.decode(String.self, forKey: .preDeleteHook, or: "")
    postDeleteHook = try container.decode(String.self, forKey: .postDeleteHook, or: "")
    linkedPaths = try container.decode(String.self, forKey: .linkedPaths, or: "")
    copiedPaths = try container.decode(String.self, forKey: .copiedPaths, or: "")
    preferredAgentID = Self.override(
      try container.decodeIfPresent(String.self, forKey: .preferredAgentID))
    // No `override(_:)`: `""` is this field's only way to say "no flags here".
    agentFlags = try container.decodeIfPresent(String.self, forKey: .agentFlags)
    autoStartAgent = try container.decodeIfPresent(Bool.self, forKey: .autoStartAgent)
    // Absent is "follow the global", not "what `autoStartAgent` says": seeding
    // it from the other turns the global into an override on every load.
    autoStartAgentOnCreate = try container.decodeIfPresent(
      Bool.self, forKey: .autoStartAgentOnCreate)
    opensTerminalOnSelect = try container.decodeIfPresent(Bool.self, forKey: .opensTerminalOnSelect)
    opensTerminalOnCreate = try container.decodeIfPresent(Bool.self, forKey: .opensTerminalOnCreate)
    // Tolerated: an order a newer build named costs the override, not the project.
    worktreeSortOrder = container.decodeTolerantly(
      WorktreeSortOrder.self, forKey: .worktreeSortOrder)
    showsActiveWorktreesFirst = try container.decodeIfPresent(
      Bool.self, forKey: .showsActiveWorktreesFirst)
    defaultShell = Self.override(try container.decodeIfPresent(String.self, forKey: .defaultShell))
    iconGlyph = Self.override(try container.decodeIfPresent(String.self, forKey: .iconGlyph))
    // Tolerated: a tint that is not a number costs the tint, not the file.
    iconTint = ProjectIcon.validTint(container.decodeTolerantly(Int.self, forKey: .iconTint))
    // Lossy: an answer that will not decode costs that answer and not the
    // project's others, and its hooks are asked about again.
    sharedHooks = container.decodeLossy(SharedHooksDecision.self, forKey: .sharedHooks)
  }

  private static func override(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }

  /// Stores the answer for `digest`, replacing any earlier one about those
  /// bytes and moving it to the front, so the longest unasked-about falls off.
  public mutating func recordSharedHooks(file digest: String, trusted: Bool) {
    sharedHooks.removeAll { $0.digest == digest }
    sharedHooks.insert(SharedHooksDecision(digest: digest, trusted: trusted), at: 0)
    if sharedHooks.count > Self.rememberedSharedHooks {
      sharedHooks.removeLast(sharedHooks.count - Self.rememberedSharedHooks)
    }
  }

  /// The answer stored about the file with digest `digest`, if the user has
  /// given one.
  func decision(aboutFile digest: String) -> SharedHooksDecision? {
    sharedHooks.first { $0.digest == digest }
  }

  /// Whether the hooks in `shared` came from a file the user said yes to.
  /// Settings that came from no file trust nothing.
  public func trustsHooks(of shared: SharedProjectSettings) -> Bool {
    guard shared.hasHooks, let digest = shared.digest else { return false }
    return decision(aboutFile: digest)?.trusted == true
  }

  /// Whether `shared` has hooks in a file the user has not yet been asked
  /// about.
  public func needsHookDecision(for shared: SharedProjectSettings) -> Bool {
    guard shared.hasHooks, let digest = shared.digest else { return false }
    return decision(aboutFile: digest) == nil
  }

  /// These settings with the repository's own filling only the gaps the user
  /// left, and its hooks only once trusted; see docs/design/settings.md.
  public func layered(over shared: SharedProjectSettings?) -> ProjectSettings {
    // Normalised on both paths, with or without a file to fall through to, or
    // the two disagree over the same stored value.
    var result = self
    result.iconGlyph = ProjectIcon.symbolName(iconGlyph)
    guard let shared else { return result }
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
    result.iconGlyph = result.iconGlyph ?? ProjectIcon.symbolName(shared.iconGlyph)
    result.iconTint = iconTint ?? ProjectIcon.validTint(shared.iconTint)
    result.linkedPaths = linkedPaths.isEmpty ? shared.linkedPaths ?? "" : linkedPaths
    result.copiedPaths = copiedPaths.isEmpty ? shared.copiedPaths ?? "" : copiedPaths
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

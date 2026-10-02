import Foundation

/// Per-project preferences, edited in the project's settings panel. Worktree
/// fields are overrides, `nil` following the global; see Docs/design/settings.md.
public struct ProjectSettings: Codable, Hashable, Sendable {
  public var worktreeDirectory: String?
  public var branchPrefix: String?
  /// The branch merges are measured against. `nil` detects it: `origin/HEAD`,
  /// then `origin/main`, `origin/master`, `main`, `master`.
  public var defaultBranch: String?

  /// Scripts run through the user's login shell around `git worktree add` and
  /// `remove`. Empty means no hook; see Docs/design/hooks.md.
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
  /// no flags at all; see Docs/design/agents.md for why a repo file cannot say this.
  public var agentFlags: String?
  /// Whether new tabs here start the agent. `nil` follows the global.
  public var autoStartsAgent: Bool?
  /// Whether the tab a worktree created here opens starts the agent. `nil`
  /// follows the global.
  public var autoStartsAgentOnCreate: Bool?

  /// Whether a worktree here opens a terminal when it is turned to. `nil`
  /// follows the global.
  public var opensTerminalOnSelect: Bool?

  /// The order this project's worktree rows are listed in. `nil` follows
  /// the global.
  public var worktreeSortOrder: WorktreeSortOrder?
  /// Whether this project's active worktrees are listed above the rest.
  /// `nil` follows the global.
  public var showsActiveWorktreesFirst: Bool?

  /// Whether a worktree created here opens a terminal once the create, and
  /// any post-create hook, is done. `nil` follows the global.
  public var opensTerminalOnCreate: Bool?

  /// Shell override by path. `nil` follows the global;
  /// `ShellChoice.loginShellID` means `$SHELL` here whatever it says.
  public var preferredShellID: String?

  /// The sidebar glyph: an SF Symbol name from `ProjectIcon.symbols`. `nil`,
  /// or any other string, draws the folder.
  public var iconGlyph: String?
  /// A slot in the theme's sixteen ANSI colours, or `nil` for the chrome's
  /// own text colour. Applies to symbols and the folder alike.
  public var iconTint: Int?

  /// One answer per `.multishell.json`, against the sha256 of its bytes; see
  /// settings.md.
  var trustDecisions: [TrustDecision]

  init(
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
    autoStartsAgent: Bool? = nil,
    autoStartsAgentOnCreate: Bool? = nil,
    opensTerminalOnSelect: Bool? = nil,
    opensTerminalOnCreate: Bool? = nil,
    worktreeSortOrder: WorktreeSortOrder? = nil,
    showsActiveWorktreesFirst: Bool? = nil,
    preferredShellID: String? = nil,
    iconGlyph: String? = nil,
    iconTint: Int? = nil
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
    self.autoStartsAgent = autoStartsAgent
    self.autoStartsAgentOnCreate = autoStartsAgentOnCreate
    self.opensTerminalOnSelect = opensTerminalOnSelect
    self.opensTerminalOnCreate = opensTerminalOnCreate
    self.worktreeSortOrder = worktreeSortOrder
    self.showsActiveWorktreesFirst = showsActiveWorktreesFirst
    self.preferredShellID = preferredShellID
    self.iconGlyph = iconGlyph
    self.iconTint = ProjectIcon.usableTint(iconTint)
    self.trustDecisions = []
  }

  /// The answers keep the key they had when they covered hooks alone, as a new
  /// one would drop every answer already given; the shell and auto-start keep
  /// their old keys too.
  private enum CodingKeys: String, CodingKey {
    case worktreeDirectory, branchPrefix, defaultBranch
    case preCreateHook, postCreateHook, preDeleteHook, postDeleteHook
    case linkedPaths, copiedPaths
    case preferredAgentID, agentFlags
    case autoStartsAgent = "autoStartAgent"
    case autoStartsAgentOnCreate = "autoStartAgentOnCreate"
    case opensTerminalOnSelect, worktreeSortOrder, showsActiveWorktreesFirst, opensTerminalOnCreate
    case preferredShellID = "defaultShell"
    case iconGlyph, iconTint
    case trustDecisions = "sharedHooks"
  }

  /// `""` overrides to "none" for the four fields with no other spelling for
  /// it, and is noise elsewhere; see Docs/design/settings.md.
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
    preferredAgentID = try container.decodeIfPresent(
      String.self, forKey: .preferredAgentID)?.presence
    // No `presence`: `""` is this field's only way to say "no flags here".
    agentFlags = try container.decodeIfPresent(String.self, forKey: .agentFlags)
    autoStartsAgent = try container.decodeIfPresent(Bool.self, forKey: .autoStartsAgent)
    // Absent is "follow the global", not "what `autoStartsAgent` says": seeding
    // it from the other turns the global into an override on every load.
    autoStartsAgentOnCreate = try container.decodeIfPresent(
      Bool.self, forKey: .autoStartsAgentOnCreate)
    opensTerminalOnSelect = try container.decodeIfPresent(Bool.self, forKey: .opensTerminalOnSelect)
    opensTerminalOnCreate = try container.decodeIfPresent(Bool.self, forKey: .opensTerminalOnCreate)
    // Tolerated: an order a newer build named costs the override, not the project.
    worktreeSortOrder = container.decodeTolerantly(
      WorktreeSortOrder.self, forKey: .worktreeSortOrder)
    showsActiveWorktreesFirst = try container.decodeIfPresent(
      Bool.self, forKey: .showsActiveWorktreesFirst)
    preferredShellID = try container.decodeIfPresent(
      String.self, forKey: .preferredShellID)?.presence
    iconGlyph = try container.decodeIfPresent(String.self, forKey: .iconGlyph)?.presence
    // Tolerated: a tint that is not a number costs the tint, not the file.
    iconTint = ProjectIcon.usableTint(container.decodeTolerantly(Int.self, forKey: .iconTint))
    // Lossy: an answer that will not decode costs that answer and not the
    // project's others, and its hooks are asked about again.
    trustDecisions = container.decodeLossy(
      TrustDecision.self, forKey: .trustDecisions)
  }
}

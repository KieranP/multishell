/// The whole sidebar, every open tab, and the current look, as one value.
/// Collections are flat and joined by id; array order is display order.
public struct Workspace: Codable, Hashable, Sendable {
  public var projects: [Project] = []
  public var worktrees: [Worktree] = []
  public var sessions: [TerminalSession] = []
  public var tabs: [TerminalTab] = []
  /// The groups of tabs each worktree is divided into, in display order
  /// left to right; see `TabGroup`. A worktree with tabs has at least one.
  var tabGroups: [TabGroup] = []

  public var selectedWorktreeID: Worktree.ID?
  /// Which group a worktree's keystrokes go to. Here and not on `Worktree`
  /// for the same reason `worktreeNames` is.
  var focusedGroupByWorktree: [Worktree.ID: TabGroup.ID] = [:]
  /// The user's own name for a worktree. Here and not on `Worktree`, whose
  /// records git replaces wholesale on every refresh.
  var worktreeNames: [Worktree.ID: String] = [:]

  public var appearance = Appearance()
  public var worktreeDefaults = WorktreeSettings()
  public var notifications = NotificationPreference.off
  /// Catalogue id of the agent New Agent Tab starts, or `nil` for none.
  /// Projects may override it in `ProjectSettings`.
  public var preferredAgentID: String?
  /// What `AgentCatalogue.customID` runs, as the user typed it.
  public var customAgentCommand = ""
  /// Extra arguments each agent is started with, by catalogue id, as typed.
  /// Per agent, not one line; see Docs/design/agents.md.
  public var agentFlags: [String: String] = [:]
  /// New Tab, and the first tab of a worktree turned to, start the
  /// preferred agent rather than a plain shell. Projects may override it.
  public var autoStartAgent = false
  /// The same for the tab a newly created worktree opens, asked separately:
  /// a worktree is often made for an agent by someone whose tabs are shells.
  public var autoStartAgentOnCreate = false
  /// Path of the shell new tabs run, `ShellCatalogue.customID` for the one
  /// typed in `customShellPath`, or `nil` for `$SHELL`.
  public var preferredShellID: String?
  /// What `ShellCatalogue.customID` runs, as the user typed it.
  public var customShellPath = ""
  /// Catalogue id of the editor Open in Editor uses, or `nil` for none.
  public var preferredEditorID: String?
  /// What `EditorCatalogue.customID` runs, with `{path}` for the worktree.
  public var customEditorCommand = ""
  /// Selecting a worktree with no tabs opens one. Off, Cmd+T or the
  /// actions menu does.
  public var opensTerminalOnSelect = true
  /// A worktree just created opens its first terminal. Asked separately from
  /// `opensTerminalOnSelect`: a create is asked for, not looked at.
  public var opensTerminalOnCreate = true
  /// The order worktree rows are listed in under their project. Projects
  /// may override it in `ProjectSettings`.
  public var worktreeSortOrder = WorktreeSortOrder.default
  /// Busy worktrees listed above the rest, each group then in
  /// `worktreeSortOrder`. Off by default: self-reordering lists surprise.
  public var showsActiveWorktreesFirst = false
  /// Ask before `git worktree remove`. Off is for people who remove
  /// worktrees all day; the default protects everyone else.
  public var confirmsWorktreeRemoval = true
  /// Delete a worktree's branch along with it every time. Off, the removal
  /// asks whether the branch goes too.
  public var deletesBranchWithWorktree = false
  /// A removed worktree's directory goes to the Trash. Off, it is deleted
  /// outright, for trees too large to keep there.
  public var trashesRemovedWorktrees = true
  /// How long a project hook may run before it is stopped and reported.
  /// Zero is no limit.
  public var hookTimeoutSeconds = Self.defaultHookTimeoutSeconds
  /// What the git badge on a row and a card counts.
  public var gitStatusIndicator = GitStatusIndicator.default

  static let defaultHookTimeoutSeconds = 60

  /// `hookTimeoutSeconds` as the runner takes it; `nil` for no limit.
  public var hookTimeout: Duration? {
    hookTimeoutSeconds > 0 ? .seconds(hookTimeoutSeconds) : nil
  }

  public init() {}

  /// Every field defaults, and every collection but projects is lossy;
  /// see Docs/design/state-and-store.md.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    projects = try container.decode([Project].self, forKey: .projects, or: [])
    worktrees = container.decodeLossy(Worktree.self, forKey: .worktrees)
    sessions = container.decodeLossy(TerminalSession.self, forKey: .sessions)
    tabs = container.decodeLossy(TerminalTab.self, forKey: .tabs)
    tabGroups = container.decodeLossy(TabGroup.self, forKey: .tabGroups)
    selectedWorktreeID = try container.decodeIfPresent(
      Worktree.ID.self, forKey: .selectedWorktreeID)
    focusedGroupByWorktree = try container.decode(
      [Worktree.ID: TabGroup.ID].self, forKey: .focusedGroupByWorktree, or: [:])
    worktreeNames = try container.decode(
      [Worktree.ID: String].self, forKey: .worktreeNames, or: [:])
    appearance = try container.decode(Appearance.self, forKey: .appearance, or: Appearance())
    worktreeDefaults = try container.decode(
      WorktreeSettings.self, forKey: .worktreeDefaults, or: WorktreeSettings())
    notifications = container.decodeTolerantly(
      NotificationPreference.self, forKey: .notifications, or: .off)
    preferredAgentID = try container.decodeIfPresent(String.self, forKey: .preferredAgentID)
    customAgentCommand = try container.decode(String.self, forKey: .customAgentCommand, or: "")
    agentFlags = try container.decode([String: String].self, forKey: .agentFlags, or: [:])
    autoStartAgent = try container.decode(Bool.self, forKey: .autoStartAgent, or: false)
    // State from before the two were split says one thing about both.
    autoStartAgentOnCreate = try container.decode(
      Bool.self, forKey: .autoStartAgentOnCreate, or: autoStartAgent)
    preferredShellID = try container.decodeIfPresent(String.self, forKey: .preferredShellID)
    customShellPath = try container.decode(String.self, forKey: .customShellPath, or: "")
    preferredEditorID = try container.decodeIfPresent(String.self, forKey: .preferredEditorID)
    customEditorCommand = try container.decode(String.self, forKey: .customEditorCommand, or: "")
    opensTerminalOnSelect = try container.decode(
      Bool.self, forKey: .opensTerminalOnSelect, or: true)
    // Before the two were split a create opened its terminal through the
    // selection that follows it, so older state keeps what it said.
    opensTerminalOnCreate = try container.decode(
      Bool.self, forKey: .opensTerminalOnCreate, or: opensTerminalOnSelect)
    // Tolerated: a state file from a newer build may name an order this
    // build does not have, and that must not cost the sidebar.
    worktreeSortOrder = container.decodeTolerantly(
      WorktreeSortOrder.self, forKey: .worktreeSortOrder, or: .default)
    showsActiveWorktreesFirst = try container.decode(
      Bool.self, forKey: .showsActiveWorktreesFirst, or: false)
    confirmsWorktreeRemoval = try container.decode(
      Bool.self, forKey: .confirmsWorktreeRemoval, or: true)
    deletesBranchWithWorktree = try container.decode(
      Bool.self, forKey: .deletesBranchWithWorktree, or: false)
    trashesRemovedWorktrees = try container.decode(
      Bool.self, forKey: .trashesRemovedWorktrees, or: true)
    hookTimeoutSeconds = try container.decode(
      Int.self, forKey: .hookTimeoutSeconds, or: Self.defaultHookTimeoutSeconds)
    // Tolerated for the reason `worktreeSortOrder` is: a newer build may
    // name a kind this one has not got.
    gitStatusIndicator = container.decodeTolerantly(
      GitStatusIndicator.self, forKey: .gitStatusIndicator, or: .default)

    // A file written before groups names no group but says which tab was
    // active. Read here, or `repairReferences` falls back to the last tab.
    let legacy = try? decoder.container(keyedBy: LegacyKeys.self)
    let wasActive = legacy?.decodeTolerantly(
      [Worktree.ID: TerminalTab.ID].self, forKey: .activeTabByWorktree)
    adoptUngroupedTabs(activeByWorktree: wasActive ?? [:])
  }

  /// `preferredShellID` keeps `defaultShell`, the key it was written under.
  private enum CodingKeys: String, CodingKey {
    case projects, worktrees, sessions, tabs, tabGroups
    case selectedWorktreeID, focusedGroupByWorktree, worktreeNames
    case appearance, worktreeDefaults, notifications
    case preferredAgentID, customAgentCommand, agentFlags, autoStartAgent, autoStartAgentOnCreate
    case preferredShellID = "defaultShell"
    case customShellPath, preferredEditorID, customEditorCommand
    case opensTerminalOnSelect, opensTerminalOnCreate, worktreeSortOrder, showsActiveWorktreesFirst
    case confirmsWorktreeRemoval, deletesBranchWithWorktree, trashesRemovedWorktrees
    case hookTimeoutSeconds, gitStatusIndicator
  }

  /// Keys no property answers to any more, read only to carry what an older
  /// state file said into the shape that replaced it.
  private enum LegacyKeys: String, CodingKey {
    case activeTabByWorktree
  }
}

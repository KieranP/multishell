/// The whole sidebar, every open tab, and the current look, as one value.
/// Collections are flat and joined by id; array order is display order.
public struct Workspace: Codable, Hashable, Sendable {
  public internal(set) var projects: [Project] = []
  public internal(set) var worktrees: [Worktree] = []
  public internal(set) var sessions: [TerminalSession] = []
  public internal(set) var tabs: [TerminalTab] = []
  /// The groups of tabs each worktree is divided into, in display order
  /// left to right; see `TabGroup`. A worktree with tabs has at least one.
  var tabGroups: [TabGroup] = []

  public internal(set) var selectedWorktreeID: Worktree.ID?
  /// Which group a worktree's keystrokes go to. Here and not on `Worktree`
  /// for the same reason `customWorktreeNames` is.
  var focusedGroupByWorktree: [Worktree.ID: TabGroup.ID] = [:]
  /// The user's own name for a worktree. Here and not on `Worktree`, whose
  /// records git replaces wholesale on every refresh.
  var customWorktreeNames: [Worktree.ID: String] = [:]

  public internal(set) var appearance = Appearance()
  public internal(set) var worktreeDefaults = WorktreeSettings()
  public internal(set) var notificationPreference = NotificationPreference.off
  /// Catalogue id of the agent New Agent Tab starts, or `nil` for none.
  /// Projects may override it in `ProjectSettings`.
  public internal(set) var preferredAgentID: String?
  /// What `AgentCatalogue.customID` runs, as the user typed it.
  public internal(set) var customAgentCommand = ""
  /// Extra arguments each agent is started with, by catalogue id, as typed.
  /// Per agent, not one line; see Docs/design/agents.md.
  public internal(set) var agentFlags: [String: String] = [:]
  /// New Tab, and the first tab of a worktree turned to, start the
  /// preferred agent rather than a plain shell. Projects may override it.
  public internal(set) var autoStartsAgent = false
  /// The same for the tab a newly created worktree opens, asked separately:
  /// a worktree is often made for an agent by someone whose tabs are shells.
  public internal(set) var autoStartsAgentOnCreate = false
  /// Path of the shell new tabs run, `ShellChoice.customID` for the one
  /// typed in `customShellPath`, or `nil` for `$SHELL`.
  public internal(set) var preferredShellID: String?
  /// What `ShellChoice.customID` runs, as the user typed it.
  public internal(set) var customShellPath = ""
  /// Catalogue id of the editor Open in Editor uses, or `nil` for none.
  public internal(set) var preferredEditorID: String?
  /// What `EditorCatalogue.customID` runs, with `{path}` for the worktree.
  public internal(set) var customEditorCommand = ""
  /// Selecting a worktree with no tabs opens one. Off, Cmd+T or the
  /// actions menu does.
  public internal(set) var opensTerminalOnSelect = true
  /// A worktree just created opens its first terminal. Asked separately from
  /// `opensTerminalOnSelect`: a create is asked for, not looked at.
  public internal(set) var opensTerminalOnCreate = true
  /// The order worktree rows are listed in under their project. Projects
  /// may override it in `ProjectSettings`.
  public internal(set) var worktreeSortOrder = WorktreeSortOrder.default
  /// Active worktrees listed above the rest, each group then in
  /// `worktreeSortOrder`. Off by default: self-reordering lists surprise.
  public internal(set) var showsActiveWorktreesFirst = false
  /// Ask before `git worktree remove`. Off is for people who remove
  /// worktrees all day; the default protects everyone else.
  public internal(set) var confirmsWorktreeRemoval = true
  /// Delete a worktree's branch along with it every time. Off, the removal
  /// asks whether the branch goes too.
  public internal(set) var deletesBranchWithWorktree = false
  /// A removed worktree's directory goes to the Trash. Off, it is deleted
  /// outright, for trees too large to keep there.
  public internal(set) var trashesRemovedWorktrees = true
  /// How long a project hook may run before it is stopped and reported.
  /// Zero is no limit.
  public internal(set) var projectHookTimeoutSeconds = Self.defaultProjectHookTimeoutSeconds
  /// What the git badge on a row and a card counts.
  public internal(set) var gitStatusIndicator = GitStatusIndicator.default

  private static let defaultProjectHookTimeoutSeconds = 60

  /// `projectHookTimeoutSeconds` as the runner takes it; `nil` for no limit.
  public var projectHookTimeout: Duration? {
    projectHookTimeoutSeconds > 0 ? .seconds(projectHookTimeoutSeconds) : nil
  }

  init() {}

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
    customWorktreeNames = try container.decode(
      [Worktree.ID: String].self, forKey: .customWorktreeNames, or: [:])
    appearance = try container.decode(Appearance.self, forKey: .appearance, or: Appearance())
    worktreeDefaults = try container.decode(
      WorktreeSettings.self, forKey: .worktreeDefaults, or: WorktreeSettings())
    notificationPreference = container.decodeTolerantly(
      NotificationPreference.self, forKey: .notificationPreference, or: .off)
    preferredAgentID = try container.decodeIfPresent(String.self, forKey: .preferredAgentID)
    customAgentCommand = try container.decode(String.self, forKey: .customAgentCommand, or: "")
    agentFlags = try container.decode([String: String].self, forKey: .agentFlags, or: [:])
    autoStartsAgent = try container.decode(Bool.self, forKey: .autoStartsAgent, or: false)
    // State from before the two were split says one thing about both.
    autoStartsAgentOnCreate = try container.decode(
      Bool.self, forKey: .autoStartsAgentOnCreate, or: autoStartsAgent)
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
    projectHookTimeoutSeconds = try container.decode(
      Int.self, forKey: .projectHookTimeoutSeconds, or: Self.defaultProjectHookTimeoutSeconds)
    // Tolerated for the reason `worktreeSortOrder` is: a newer build may
    // name a kind this one has not got.
    gitStatusIndicator = container.decodeTolerantly(
      GitStatusIndicator.self, forKey: .gitStatusIndicator, or: .default)

    // A file written before groups names no group but says which tab was
    // active. Read here, or `repairReferences` falls back to the last tab.
    let legacy = try? decoder.container(keyedBy: LegacyKeys.self)
    let legacyShownTabs = legacy?.decodeTolerantly(
      [Worktree.ID: TerminalTab.ID].self, forKey: .activeTabByWorktree)
    adoptUngroupedTabs(shownTabByWorktree: legacyShownTabs ?? [:])
  }

  /// Renamed fields keep the keys they were written under: `defaultShell`,
  /// `worktreeNames`, `notifications` and the auto-start pair's `autoStartAgent…`.
  private enum CodingKeys: String, CodingKey {
    case projects, worktrees, sessions, tabs, tabGroups
    case selectedWorktreeID, focusedGroupByWorktree
    case customWorktreeNames = "worktreeNames"
    case appearance, worktreeDefaults
    case notificationPreference = "notifications"
    case preferredAgentID, customAgentCommand, agentFlags
    case autoStartsAgent = "autoStartAgent"
    case autoStartsAgentOnCreate = "autoStartAgentOnCreate"
    case preferredShellID = "defaultShell"
    case customShellPath, preferredEditorID, customEditorCommand
    case opensTerminalOnSelect, opensTerminalOnCreate, worktreeSortOrder, showsActiveWorktreesFirst
    case confirmsWorktreeRemoval, deletesBranchWithWorktree, trashesRemovedWorktrees
    case projectHookTimeoutSeconds = "hookTimeoutSeconds"
    case gitStatusIndicator
  }

  /// Keys no property answers to any more, read only to carry what an older
  /// state file said into the shape that replaced it.
  private enum LegacyKeys: String, CodingKey {
    case activeTabByWorktree
  }
}

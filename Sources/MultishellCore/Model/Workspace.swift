import Foundation

/// The whole sidebar, every open tab, and the current look, as one value.
/// Collections are flat and joined by id; array order is display order.
public struct Workspace: Codable, Hashable, Sendable {
  public var projects: [Project] = []
  public var worktrees: [Worktree] = []
  public var sessions: [TerminalSession] = []
  public var tabs: [TerminalTab] = []
  /// The columns of tabs each worktree is divided into, in display order
  /// left to right; see `TabGroup`. A worktree with tabs has at least one.
  public var tabGroups: [TabGroup] = []

  public var selectedWorktreeID: Worktree.ID?
  /// Which column a worktree's keystrokes go to. Here and not on `Worktree`
  /// for the same reason `worktreeNames` is.
  public var focusedGroupByWorktree: [Worktree.ID: TabGroup.ID] = [:]
  /// The user's own name for a worktree. Here and not on `Worktree`, whose
  /// records git replaces wholesale on every refresh.
  public var worktreeNames: [Worktree.ID: String] = [:]

  public var appearance = Appearance()
  public var terminalEngine: TerminalEngine = .ghostty
  public var worktreeDefaults = WorktreeSettings()
  public var notifications = NotificationPreference.default
  /// Catalogue id of the agent New Agent Tab starts, or `nil` for none.
  /// Projects may override it in `ProjectSettings`.
  public var preferredAgentID: String?
  /// What `AgentCatalogue.customID` runs, as the user typed it.
  public var customAgentCommand = ""
  /// Extra arguments each agent is started with, by catalogue id, as typed.
  /// Per agent, not one line; see docs/design/agents.md.
  public var agentFlags: [String: String] = [:]
  /// New Tab, and the first tab of a worktree turned to, start the
  /// preferred agent rather than a plain shell. Projects may override it.
  public var autoStartAgent = false
  /// The same for the tab a newly created worktree opens, asked separately:
  /// a worktree is often made for an agent by someone whose tabs are shells.
  public var autoStartAgentOnCreate = false
  /// Path of the shell new tabs run, `ShellCatalogue.customID` for the one
  /// typed in `customShellPath`, or `nil` for `$SHELL`.
  public var defaultShell: String?
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
  /// How long a project hook may run before it is stopped and reported.
  /// Zero is no limit.
  public var hookTimeoutSeconds = Self.defaultHookTimeoutSeconds

  public static let defaultHookTimeoutSeconds = 60

  public init() {}

  /// Every field defaults, and every collection but projects is lossy;
  /// see docs/design/state-and-store.md.
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
    // Tolerated, not thrown on: a state file from a newer build may name an
    // engine this build does not have, and that must not cost the sidebar.
    terminalEngine = container.decodeTolerantly(
      TerminalEngine.self, forKey: .terminalEngine, or: .ghostty)
    worktreeDefaults = try container.decode(
      WorktreeSettings.self, forKey: .worktreeDefaults, or: WorktreeSettings())
    notifications = container.decodeTolerantly(
      NotificationPreference.self, forKey: .notifications, or: .default)
    preferredAgentID = try container.decodeIfPresent(String.self, forKey: .preferredAgentID)
    customAgentCommand = try container.decode(String.self, forKey: .customAgentCommand, or: "")
    agentFlags = try container.decode([String: String].self, forKey: .agentFlags, or: [:])
    autoStartAgent = try container.decode(Bool.self, forKey: .autoStartAgent, or: false)
    // State from before the two were split says one thing about both.
    autoStartAgentOnCreate = try container.decode(
      Bool.self, forKey: .autoStartAgentOnCreate, or: autoStartAgent)
    defaultShell = try container.decodeIfPresent(String.self, forKey: .defaultShell)
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
    hookTimeoutSeconds = try container.decode(
      Int.self, forKey: .hookTimeoutSeconds, or: Self.defaultHookTimeoutSeconds)

    // A file written before columns names no group but says which tab was
    // active. Read here, or `repairReferences` falls back to the last tab.
    let legacy = try? decoder.container(keyedBy: LegacyKeys.self)
    let wasActive = legacy?.decodeTolerantly(
      [Worktree.ID: TerminalTab.ID].self, forKey: .activeTabByWorktree)
    adoptUngroupedTabs(activeByWorktree: wasActive ?? [:])
  }

  /// Keys no property answers to any more, read only to carry what an older
  /// state file said into the shape that replaced it.
  private enum LegacyKeys: String, CodingKey {
    case activeTabByWorktree
  }
}

// MARK: - Queries

extension Workspace {
  public func project(_ id: Project.ID) -> Project? {
    projects.first { $0.id == id }
  }

  public func worktree(_ id: Worktree.ID) -> Worktree? {
    worktrees.first { $0.id == id }
  }

  public func session(_ id: TerminalSession.ID) -> TerminalSession? {
    sessions.first { $0.id == id }
  }

  public func tab(_ id: TerminalTab.ID) -> TerminalTab? {
    tabs.first { $0.id == id }
  }

  public func group(_ id: TabGroup.ID) -> TabGroup? {
    tabGroups.first { $0.id == id }
  }

  public func tab(before tab: TerminalTab.ID) -> TerminalTab? {
    neighbour(of: tab, .before)
  }

  public func tab(after tab: TerminalTab.ID) -> TerminalTab? {
    neighbour(of: tab, .after)
  }

  /// Cycling stays inside the tab's own column. Backwards is a step of
  /// `count - 1` forwards, keeping the sum positive for Swift's `%`.
  private func neighbour(
    of id: TerminalTab.ID, _ direction: TerminalTab.Placement
  ) -> TerminalTab? {
    guard let current = tab(id) else { return nil }
    let siblings = tabs(in: current.groupID)
    guard let index = siblings.firstIndex(where: { $0.id == id }), siblings.count > 1 else {
      return nil
    }
    let step = direction == .after ? 1 : siblings.count - 1
    return siblings[(index + step) % siblings.count]
  }

  /// The name the user gave this worktree, or `nil` where they gave none.
  public func customName(of worktree: Worktree.ID) -> String? {
    worktreeNames[worktree]
  }

  /// What the sidebar and the header call a worktree: the user's name where
  /// there is one, else the branch, SHA or folder `Worktree.name` gives.
  public func displayName(of worktree: Worktree) -> String {
    worktreeNames[worktree.id] ?? worktree.name
  }

  public func worktrees(of project: Project.ID) -> [Worktree] {
    worktrees.filter { $0.projectID == project }
  }

  /// Every tab of a worktree, whichever column it is in.
  public func tabs(in worktree: Worktree.ID) -> [TerminalTab] {
    tabs.filter { $0.worktreeID == worktree }
  }

  /// One column's tabs, in strip order. `tabs` is one flat array whose
  /// order is display order, so a move places rather than reorders.
  public func tabs(in group: TabGroup.ID) -> [TerminalTab] {
    tabs.filter { $0.groupID == group }
  }

  /// A worktree's columns, left to right.
  public func groups(in worktree: Worktree.ID) -> [TabGroup] {
    tabGroups.filter { $0.worktreeID == worktree }
  }

  public func group(of tab: TerminalTab.ID) -> TabGroup? {
    self.tab(tab).flatMap { group($0.groupID) }
  }

  /// The column a worktree's keystrokes go to, falling back to its first so
  /// a hand-edited file still shows a strip.
  public func focusedGroup(in worktree: Worktree.ID) -> TabGroup? {
    let columns = groups(in: worktree)
    if let id = focusedGroupByWorktree[worktree], let group = columns.first(where: { $0.id == id })
    {
      return group
    }
    return columns.first
  }

  public func sessions(in worktree: Worktree.ID) -> [TerminalSession] {
    sessions.filter { $0.worktreeID == worktree }
  }

  /// The user's name for a tab, else the focused pane's starting title. What
  /// a running shell reports is runtime state the GUI layers on top.
  public func title(of tab: TerminalTab) -> String {
    if let custom = tab.customTitle { return custom }
    return session(tab.focusedSessionID)?.title ?? t("tab.shell")
  }

  public func tabOwning(_ session: TerminalSession.ID) -> TerminalTab? {
    tabs.first { $0.root.contains(session) }
  }

  public var selectedWorktree: Worktree? {
    selectedWorktreeID.flatMap(worktree)
  }

  /// The tab a column shows.
  public func activeTab(in group: TabGroup) -> TerminalTab? {
    group.activeTabID.flatMap { tab($0) }
  }

  /// The tab the user is working in: the focused column's. What Cmd+T,
  /// Close Pane, a split and a rename all act on.
  public func activeTab(in worktree: Worktree.ID) -> TerminalTab? {
    focusedGroup(in: worktree).flatMap { activeTab(in: $0) }
  }

  /// Every tab on screen for a worktree, one per column. Anything meaning
  /// "the user can see this" asks here, not `activeTab`.
  public func shownTabs(in worktree: Worktree.ID) -> [TerminalTab] {
    groups(in: worktree).compactMap { activeTab(in: $0) }
  }

  public var theme: Theme {
    appearance.theme()
  }

  // These read `project.settings`, so the project must be the one the model
  // resolved (`AppModel.resolved`), not one out of `workspace.projects`.

  public func worktreeSettings(for project: Project) -> WorktreeSettings {
    project.settings.effective(defaults: worktreeDefaults)
  }

  /// The agent New Agent Tab starts in this project, or `nil` for none.
  public func preferredAgentID(for project: Project) -> String? {
    AgentCatalogue.effectiveID(
      global: preferredAgentID, override: project.settings.preferredAgentID)
  }

  /// The project's flag line where it overrides, else the global one for
  /// that agent. Blank is the override to none; see settings.md.
  public func agentFlags(for project: Project, agent id: String) -> String {
    project.settings.agentFlags ?? agentFlags[id] ?? ""
  }

  /// Whether a new tab in this project starts its agent: the project's say
  /// when it has one, else the global, and only when an agent is in force.
  public func autoStartsAgent(for project: Project) -> Bool {
    (project.settings.autoStartAgent ?? autoStartAgent) && preferredAgentID(for: project) != nil
  }

  /// The same for the tab a worktree created here opens.
  public func autoStartsAgentOnCreate(for project: Project) -> Bool {
    (project.settings.autoStartAgentOnCreate ?? autoStartAgentOnCreate)
      && preferredAgentID(for: project) != nil
  }

  /// Whether a worktree in this project opens a terminal when it is turned
  /// to: the project's say when it has one, else the global.
  public func opensTerminalOnSelect(for project: Project) -> Bool {
    project.settings.opensTerminalOnSelect ?? opensTerminalOnSelect
  }

  /// The same for a worktree just created here.
  public func opensTerminalOnCreate(for project: Project) -> Bool {
    project.settings.opensTerminalOnCreate ?? opensTerminalOnCreate
  }

  /// The order this project's worktree rows are listed in: the project's
  /// say when it has one, else the global.
  public func worktreeSortOrder(for project: Project) -> WorktreeSortOrder {
    project.settings.worktreeSortOrder ?? worktreeSortOrder
  }

  /// Whether this project lifts its busy worktrees to the top of its block.
  public func showsActiveWorktreesFirst(for project: Project) -> Bool {
    project.settings.showsActiveWorktreesFirst ?? showsActiveWorktreesFirst
  }

  /// The shell a new tab in this project runs, or `nil` for `$SHELL`.
  public func defaultShell(for project: Project) -> String? {
    ShellCatalogue.effectivePath(
      global: defaultShell, override: project.settings.defaultShell, customPath: customShellPath)
  }

  /// The editor Open in Editor uses, or `nil` for none.
  public var effectiveEditorID: String? {
    EditorCatalogue.effectiveID(preferredEditorID)
  }

  /// `hookTimeoutSeconds` as the runner takes it; `nil` for no limit.
  public var hookTimeout: Duration? {
    hookTimeoutSeconds > 0 ? .seconds(hookTimeoutSeconds) : nil
  }
}

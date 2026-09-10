import Foundation

/// The whole sidebar, every open tab, and the current look, as one value.
///
/// Collections are flat and joined by id rather than nested, so a change to
/// one worktree does not rewrite its project. Array order is display order.
public struct Workspace: Codable, Hashable, Sendable {
  public var projects: [Project] = []
  public var worktrees: [Worktree] = []
  public var sessions: [TerminalSession] = []
  public var tabs: [TerminalTab] = []
  /// The columns of tabs each worktree is divided into, in display order
  /// left to right; see `TabGroup`. A worktree with tabs has at least one.
  public var tabGroups: [TabGroup] = []

  public var selectedWorktreeID: Worktree.ID?
  /// Which column a worktree's keystrokes go to: the one whose active tab
  /// `activeTab(in:)` answers with, and the one a new tab opens in. Kept
  /// here rather than on `Worktree` for the same reason `worktreeNames` is,
  /// git's list replacing those records wholesale on every refresh.
  public var focusedGroupByWorktree: [Worktree.ID: TabGroup.ID] = [:]
  /// The user's own name for a worktree, where they gave one. Kept here
  /// rather than on `Worktree` because git's list replaces those wholesale
  /// on every refresh, and a name the user typed must outlive that. An
  /// entry goes when its worktree does, so a removed worktree leaves
  /// nothing behind in the state file.
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
  /// New Tab, and the first tab of a worktree turned to, start the
  /// preferred agent rather than a plain shell. Projects may override it.
  public var autoStartAgent = false
  /// The same for the tab a newly created worktree opens, asked about
  /// separately: a worktree is often made for an agent to work in by
  /// someone whose own tabs are shells. Projects may override it.
  public var autoStartAgentOnCreate = false
  /// Path of the shell new tabs run, `ShellCatalogue.customID` for the path
  /// typed in `customShellPath`, or `nil` for `$SHELL`. Projects may
  /// override it in `ProjectSettings`.
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
  /// A worktree just created opens its first terminal. Asked separately
  /// from `opensTerminalOnSelect`, since a create is a worktree asked for
  /// rather than one looked at. Projects may override it in
  /// `ProjectSettings`.
  public var opensTerminalOnCreate = true
  /// The order worktree rows are listed in under their project. Projects
  /// may override it in `ProjectSettings`.
  public var worktreeSortOrder = WorktreeSortOrder.default
  /// Worktrees with a terminal open or a state reported are listed above
  /// the rest, each group then in `worktreeSortOrder`. Projects may
  /// override it. Off by default: a list that reorders itself as agents
  /// report in is a surprise until it is asked for.
  public var showsActiveWorktreesFirst = false
  /// Ask before `git worktree remove`. Off is for people who remove
  /// worktrees all day and trust themselves; the default protects everyone
  /// else.
  public var confirmsWorktreeRemoval = true
  /// Delete a worktree's branch along with it every time. Off, the removal
  /// asks whether the branch goes too.
  public var deletesBranchWithWorktree = false
  /// How long a project hook may run before it is stopped and reported.
  /// Zero is no limit.
  public var hookTimeoutSeconds = Self.defaultHookTimeoutSeconds

  public static let defaultHookTimeoutSeconds = 60

  public init() {}

  /// Every field has a default, so a state file written before a field
  /// existed still loads. Without this, adding a property here would make
  /// the app forget every project on the next launch.
  ///
  /// Worktrees, sessions, tabs and groups drop a broken element rather than
  /// failing the file: worktrees are re-read from git on the first refresh
  /// and a tab is a fresh shell either way. Projects stay strict, because
  /// dropping one silently is what the `.broken.json` backup exists to
  /// prevent. `repairReferences` then removes what pointed at a dropped
  /// element.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    projects = try container.decodeIfPresent([Project].self, forKey: .projects) ?? []
    worktrees = container.decodeLossy(Worktree.self, forKey: .worktrees)
    sessions = container.decodeLossy(TerminalSession.self, forKey: .sessions)
    tabs = container.decodeLossy(TerminalTab.self, forKey: .tabs)
    tabGroups = container.decodeLossy(TabGroup.self, forKey: .tabGroups)
    selectedWorktreeID = try container.decodeIfPresent(
      Worktree.ID.self, forKey: .selectedWorktreeID)
    focusedGroupByWorktree =
      try container.decodeIfPresent(
        [Worktree.ID: TabGroup.ID].self, forKey: .focusedGroupByWorktree) ?? [:]
    worktreeNames =
      try container.decodeIfPresent([Worktree.ID: String].self, forKey: .worktreeNames) ?? [:]
    appearance = try container.decodeIfPresent(Appearance.self, forKey: .appearance) ?? Appearance()
    // `try?`, not `try`: a state file from a newer build may name an engine
    // this build does not have, and that must not cost the sidebar.
    terminalEngine =
      (try? container.decodeIfPresent(TerminalEngine.self, forKey: .terminalEngine)) ?? .ghostty
    worktreeDefaults =
      try container.decodeIfPresent(WorktreeSettings.self, forKey: .worktreeDefaults)
      ?? WorktreeSettings()
    notifications =
      (try? container.decodeIfPresent(NotificationPreference.self, forKey: .notifications))
      ?? .default
    preferredAgentID = try container.decodeIfPresent(String.self, forKey: .preferredAgentID)
    customAgentCommand =
      try container.decodeIfPresent(String.self, forKey: .customAgentCommand) ?? ""
    autoStartAgent = try container.decodeIfPresent(Bool.self, forKey: .autoStartAgent) ?? false
    // State from before the two were split says one thing about both.
    autoStartAgentOnCreate =
      try container.decodeIfPresent(Bool.self, forKey: .autoStartAgentOnCreate) ?? autoStartAgent
    defaultShell = try container.decodeIfPresent(String.self, forKey: .defaultShell)
    customShellPath = try container.decodeIfPresent(String.self, forKey: .customShellPath) ?? ""
    preferredEditorID = try container.decodeIfPresent(String.self, forKey: .preferredEditorID)
    customEditorCommand =
      try container.decodeIfPresent(String.self, forKey: .customEditorCommand) ?? ""
    opensTerminalOnSelect =
      try container.decodeIfPresent(Bool.self, forKey: .opensTerminalOnSelect) ?? true
    // Before the two were split a create opened its terminal by going
    // through the selection that follows it, so state that predates the
    // field keeps what it said about selecting.
    opensTerminalOnCreate =
      try container.decodeIfPresent(Bool.self, forKey: .opensTerminalOnCreate)
      ?? opensTerminalOnSelect
    // `try?`: a state file from a newer build may name an order this build
    // does not have, and that must not cost the sidebar.
    worktreeSortOrder =
      (try? container.decodeIfPresent(WorktreeSortOrder.self, forKey: .worktreeSortOrder))
      ?? WorktreeSortOrder.default
    showsActiveWorktreesFirst =
      try container.decodeIfPresent(Bool.self, forKey: .showsActiveWorktreesFirst) ?? false
    confirmsWorktreeRemoval =
      try container.decodeIfPresent(Bool.self, forKey: .confirmsWorktreeRemoval) ?? true
    deletesBranchWithWorktree =
      try container.decodeIfPresent(Bool.self, forKey: .deletesBranchWithWorktree) ?? false
    hookTimeoutSeconds =
      try container.decodeIfPresent(Int.self, forKey: .hookTimeoutSeconds)
      ?? Self.defaultHookTimeoutSeconds

    // A file written before tabs sat in columns names no group and says
    // which tab each worktree had active. Read here rather than left to
    // `repairReferences`, which takes no arguments and would have to fall
    // back to the last tab: what the user was looking at is theirs, and an
    // upgrade quietly changing it is the sort of loss the lossy decode
    // exists to prevent.
    let legacy = try? decoder.container(keyedBy: LegacyKeys.self)
    let wasActive =
      (try? legacy?.decodeIfPresent(
        [Worktree.ID: TerminalTab.ID].self, forKey: .activeTabByWorktree)) ?? nil
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
    neighbour(of: tab, offset: -1)
  }

  public func tab(after tab: TerminalTab.ID) -> TerminalTab? {
    neighbour(of: tab, offset: 1)
  }

  /// Cycling stays inside the tab's own column, so a group of two tabs is a
  /// two-tab cycle rather than a walk through every tab in the worktree.
  private func neighbour(of id: TerminalTab.ID, offset: Int) -> TerminalTab? {
    guard let current = tab(id) else { return nil }
    let siblings = tabs(in: current.groupID)
    guard let index = siblings.firstIndex(where: { $0.id == id }), siblings.count > 1 else {
      return nil
    }
    return siblings[(index + offset + siblings.count) % siblings.count]
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

  /// One column's tabs, in strip order. `tabs` is one flat array and its
  /// order is display order, so a tab moved between columns is placed
  /// beside the tab it was dropped on rather than reordered here.
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

  /// The column a worktree's keystrokes go to. Falls back to the first
  /// column where the entry is missing or names a group that has gone, so a
  /// hand-edited file still shows a strip; `repairReferences` writes the
  /// entry back.
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

  /// The user's name for a tab if they gave one, else the focused pane's
  /// starting title ("Shell", or the command's name). The title a running
  /// shell reports is runtime state the GUI layers on top.
  public func title(of tab: TerminalTab) -> String {
    if let custom = tab.customTitle { return custom }
    return session(tab.focusedSessionID)?.title ?? "Shell"
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

  /// Every tab on screen for a worktree, one per column. Several tabs are
  /// visible at once now, so anything that means "the user can see this" —
  /// a Done state clearing, a notification suppressed — asks this rather
  /// than `activeTab`.
  public func shownTabs(in worktree: Worktree.ID) -> [TerminalTab] {
    groups(in: worktree).compactMap { activeTab(in: $0) }
  }

  public var theme: Theme {
    appearance.theme()
  }

  // Every resolution below reads `project.settings`, so the project handed
  // to it must be the one the model resolved (`AppModel.resolved`): a
  // repository's `.multishell.json` may supply any of these, and the record
  // straight out of `workspace.projects` has not been layered with it.

  public func worktreeSettings(for project: Project) -> WorktreeSettings {
    project.settings.effective(defaults: worktreeDefaults)
  }

  /// The agent New Agent Tab starts in this project, or `nil` for none.
  public func preferredAgentID(for project: Project) -> String? {
    AgentCatalogue.effectiveID(
      global: preferredAgentID, override: project.settings.preferredAgentID)
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

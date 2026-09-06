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

  public var selectedWorktreeID: Worktree.ID?
  public var activeTabByWorktree: [Worktree.ID: TerminalTab.ID] = [:]
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
  /// New Tab, and the first tab of a worktree, start the preferred agent
  /// rather than a plain shell. Projects may override it.
  public var autoStartAgent = false
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
  /// Worktrees, sessions and tabs drop a broken element rather than failing
  /// the file: worktrees are re-read from git on the first refresh and a tab
  /// is a fresh shell either way. Projects stay strict, because dropping one
  /// silently is what the `.broken.json` backup exists to prevent.
  /// `repairReferences` then removes what pointed at a dropped element.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    projects = try c.decodeIfPresent([Project].self, forKey: .projects) ?? []
    worktrees = c.decodeLossy(Worktree.self, forKey: .worktrees)
    sessions = c.decodeLossy(TerminalSession.self, forKey: .sessions)
    tabs = c.decodeLossy(TerminalTab.self, forKey: .tabs)
    selectedWorktreeID = try c.decodeIfPresent(Worktree.ID.self, forKey: .selectedWorktreeID)
    activeTabByWorktree =
      try c.decodeIfPresent([Worktree.ID: TerminalTab.ID].self, forKey: .activeTabByWorktree) ?? [:]
    worktreeNames = try c.decodeIfPresent([Worktree.ID: String].self, forKey: .worktreeNames) ?? [:]
    appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? Appearance()
    // `try?`, not `try`: a state file from a newer build may name an engine
    // this build does not have, and that must not cost the sidebar.
    terminalEngine =
      (try? c.decodeIfPresent(TerminalEngine.self, forKey: .terminalEngine)) ?? .ghostty
    worktreeDefaults =
      try c.decodeIfPresent(WorktreeSettings.self, forKey: .worktreeDefaults) ?? WorktreeSettings()
    notifications =
      (try? c.decodeIfPresent(NotificationPreference.self, forKey: .notifications)) ?? .default
    preferredAgentID = try c.decodeIfPresent(String.self, forKey: .preferredAgentID)
    customAgentCommand = try c.decodeIfPresent(String.self, forKey: .customAgentCommand) ?? ""
    autoStartAgent = try c.decodeIfPresent(Bool.self, forKey: .autoStartAgent) ?? false
    defaultShell = try c.decodeIfPresent(String.self, forKey: .defaultShell)
    customShellPath = try c.decodeIfPresent(String.self, forKey: .customShellPath) ?? ""
    preferredEditorID = try c.decodeIfPresent(String.self, forKey: .preferredEditorID)
    customEditorCommand = try c.decodeIfPresent(String.self, forKey: .customEditorCommand) ?? ""
    opensTerminalOnSelect =
      try c.decodeIfPresent(Bool.self, forKey: .opensTerminalOnSelect) ?? true
    confirmsWorktreeRemoval =
      try c.decodeIfPresent(Bool.self, forKey: .confirmsWorktreeRemoval) ?? true
    deletesBranchWithWorktree =
      try c.decodeIfPresent(Bool.self, forKey: .deletesBranchWithWorktree) ?? false
    hookTimeoutSeconds =
      try c.decodeIfPresent(Int.self, forKey: .hookTimeoutSeconds) ?? Self.defaultHookTimeoutSeconds
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

  public func tab(before tab: TerminalTab.ID) -> TerminalTab? {
    neighbour(of: tab, offset: -1)
  }

  public func tab(after tab: TerminalTab.ID) -> TerminalTab? {
    neighbour(of: tab, offset: 1)
  }

  private func neighbour(of id: TerminalTab.ID, offset: Int) -> TerminalTab? {
    guard let current = tab(id) else { return nil }
    let siblings = tabs(in: current.worktreeID)
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

  public func tabs(in worktree: Worktree.ID) -> [TerminalTab] {
    tabs.filter { $0.worktreeID == worktree }
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

  public func activeTab(in worktree: Worktree.ID) -> TerminalTab? {
    activeTabByWorktree[worktree].flatMap { tab($0) }
  }

  public var theme: Theme {
    appearance.theme()
  }

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

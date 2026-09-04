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

  public var appearance = Appearance()
  public var terminalEngine: TerminalEngine = .ghostty
  public var worktreeDefaults = WorktreeSettings()

  public init() {}

  /// Every field has a default, so a state file written before a field
  /// existed still loads. Without this, adding a property here would make
  /// the app forget every project on the next launch.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    projects = try c.decodeIfPresent([Project].self, forKey: .projects) ?? []
    worktrees = try c.decodeIfPresent([Worktree].self, forKey: .worktrees) ?? []
    sessions = try c.decodeIfPresent([TerminalSession].self, forKey: .sessions) ?? []
    tabs = try c.decodeIfPresent([TerminalTab].self, forKey: .tabs) ?? []
    selectedWorktreeID = try c.decodeIfPresent(Worktree.ID.self, forKey: .selectedWorktreeID)
    activeTabByWorktree =
      try c.decodeIfPresent([Worktree.ID: TerminalTab.ID].self, forKey: .activeTabByWorktree) ?? [:]
    appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? Appearance()
    terminalEngine = try c.decodeIfPresent(TerminalEngine.self, forKey: .terminalEngine) ?? .ghostty
    worktreeDefaults =
      try c.decodeIfPresent(WorktreeSettings.self, forKey: .worktreeDefaults) ?? WorktreeSettings()
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

  public func worktrees(of project: Project.ID) -> [Worktree] {
    worktrees.filter { $0.projectID == project }
  }

  public func tabs(in worktree: Worktree.ID) -> [TerminalTab] {
    tabs.filter { $0.worktreeID == worktree }
  }

  public func sessions(in worktree: Worktree.ID) -> [TerminalSession] {
    sessions.filter { $0.worktreeID == worktree }
  }

  /// What the tab strip shows: the user's name if they gave one, else the
  /// focused pane's shell-reported title.
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
}

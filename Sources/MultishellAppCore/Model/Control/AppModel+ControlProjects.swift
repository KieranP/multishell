import Foundation
import MultishellCore

extension AppModel {
  private var projectEntries: [ProjectEntry] {
    workspace.projects.map { project in
      ProjectEntry(
        id: ControlID.project(project.id),
        name: project.name,
        path: project.id,
        isMissing: missingProjects.contains(project.id),
        worktreeCount: workspace.worktrees(of: project.id).count,
      )
    }
  }

  func replyToListProjects() -> ControlReply {
    .json(projectEntries)
  }

  /// A project by its path, or by any directory in one of its worktrees: what
  /// Add Project was given, which may have been a subfolder.
  private func project(atPath path: String) -> Project? {
    workspace.project(URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path)
      ?? worktree(atPath: path).flatMap { workspace.project($0.projectID) }
  }

  /// Add Project's, a subfolder or a linked worktree adding its repository.
  func replyToAddProject(at path: String) async -> ControlReply {
    await addProject(at: URL(fileURLWithPath: path, isDirectory: true))
    guard let project = project(atPath: path) else {
      return .refused(.projectNotAdded(path: path))
    }
    return .json(["id": ControlID.project(project.id)])
  }

  /// The sidebar's Remove, without its dialog: closing a plain shell is what
  /// was asked for, and only a working agent is refused.
  func replyToRemoveProject(_ id: String, force: Bool) -> ControlReply {
    guard let project = project(withControlID: id) else { return .refused(.noProject(id: id)) }
    let sessions = workspace.worktrees(of: project.id).flatMap { worktree in
      workspace.sessions(in: worktree.id).map(\.id)
    }
    if refusesOverWorkingAgent(in: sessions, force: force) { return .refused(.agentWorking) }
    removeProject(project)
    return .done
  }

  /// The chevron, where the row is not already drawn that way. A project the
  /// filter hides has no chevron, so its stored flag is set, for after.
  func replyToSetProjectExpanded(_ id: String, expanded: Bool) -> ControlReply {
    guard let project = project(withControlID: id) else { return .refused(.noProject(id: id)) }
    guard let entry = sidebarEntries.first(where: { $0.project.id == project.id }) else {
      setExpanded(expanded, for: project)
      return .done
    }
    if entry.isExpanded != expanded { toggleExpansion(of: project) }
    return .done
  }

  /// A drop on the edge of another project's block.
  func replyToMoveProject(
    _ id: String,
    _ placement: WorkspaceTab.Placement,
    anchor: String,
  ) -> ControlReply {
    guard let moving = project(withControlID: id) else { return .refused(.noProject(id: id)) }
    guard let target = project(withControlID: anchor) else {
      return .refused(.noProject(id: anchor))
    }
    guard moving.id != target.id else { return .refused(.projectBesideItself(id: id)) }
    moveProject(moving.id, placement == .before ? .above : .below, of: target.id)
    return .done
  }

  /// The project menu's Refresh, answered once git has listed it again.
  func replyToRefreshProject(_ id: String) async -> ControlReply {
    guard let project = project(withControlID: id) else { return .refused(.noProject(id: id)) }
    guard coordinator != nil else { return .refused(.gitNotFound) }
    await refreshWorktreesOnRequest(of: project)
    // A folder gone is dimmed on its row, with no alert to answer by.
    return missingProjects.contains(project.id) ? .refused(.projectFolderMissing(id: id)) : .done
  }

  /// The project menu's Fetch; asked while one runs, it answers at once.
  func replyToFetchProject(_ id: String) async -> ControlReply {
    guard let project = project(withControlID: id) else { return .refused(.noProject(id: id)) }
    guard coordinator != nil else { return .refused(.gitNotFound) }
    await fetch(project)
    return .done
  }
}

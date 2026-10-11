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
}

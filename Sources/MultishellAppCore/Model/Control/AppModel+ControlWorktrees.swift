import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  func replyToListWorktrees(of id: String?) -> ControlReply {
    var worktrees = workspace.worktrees
    if let id {
      guard let project = project(withControlID: id) else { return .refused(.noProject(id: id)) }
      worktrees = workspace.worktrees(of: project.id)
    }
    let sessions = sessionIDsByWorktree
    return .json(worktrees.map { worktreeEntry($0, sessions: sessions) })
  }

  /// The menu's Rename or Use Branch Name, without the field.
  func replyToRenameWorktree(_ id: String, to name: String?) -> ControlReply {
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    renameWorktree(worktree.id, to: name)
    return .done
  }

  func worktreeEntry(
    _ worktree: Worktree,
    sessions: SessionIDsByWorktree,
  ) -> WorktreeEntry {
    WorktreeEntry(
      id: ControlID.worktree(worktree.id),
      project: ControlID.project(worktree.projectID),
      name: displayName(of: worktree),
      path: worktree.id,
      branch: worktree.branch,
      isPrimary: worktree.isPrimary,
      isInView: isInView(worktree),
      isBusy: isBusy(worktree.id),
      state: state(ofWorktree: worktree.id, sessions: sessions),
      tabCount: workspace.workspaceTabCount(in: worktree.id),
    )
  }

  /// As the sheet makes one. An agent or a task names the first tab;
  /// neither leaves it to the create settings.
  func replyToNewWorktree(_ order: NewWorktreeOrder) async -> ControlReply {
    guard let project = project(withControlID: order.projectID) else {
      return .refused(.noProject(id: order.projectID))
    }
    let branch = order.branch.trimmingCharacters(in: .whitespaces)
    guard !order.createsBranch || GitBranchName.isValid(branch) else {
      return .refused(.invalidBranchName(branch))
    }
    let fallback = workspace.effectiveAgentID(for: effectiveProject(project))
    let firstTab: NewWorktreeFirstTab?
    switch agentToStart(order.agentID, task: order.task, otherwise: fallback) {
    case .failure(let refusal): return .refused(refusal)
    case .success(let agentID): firstTab = agentID.map { .agent($0, task: order.task ?? "") }
    }
    guard
      let created = await createWorktree(
        branch: branch,
        basedOn: order.createsBranch ? order.startPoint : nil,
        createsBranch: order.createsBranch,
        in: project,
        firstTab: firstTab,
        takesOverTheSheet: false,
      )
    else { return .refused(.worktreeNotCreated) }
    return .json(["id": ControlID.worktree(created.id), "branch": created.name])
  }

  /// The row's Remove, without its dialog: the removal settings decide the
  /// Trash, and the branch goes only when asked.
  func replyToRemoveWorktree(_ order: WorktreeRemovalOrder) async -> ControlReply {
    let id = order.worktreeID
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    guard worktree.isRemovable else { return .refused(.worktreeNotRemovable(id: id)) }
    guard !isBusy(worktree.id) else { return .refused(.worktreeNotReady(id: id)) }
    let sessions = workspace.sessions(in: worktree.id).map(\.id)
    if refusesOverWorkingAgent(in: sessions, force: order.force) {
      return .refused(.agentWorking)
    }
    let failure = await removeWorktree(
      worktree,
      deletesBranch: order.deletesBranch,
      forcesBranchDeletion: order.forcesBranchDeletion,
    )
    switch failure {
    case .alert(let title, let message, _, _):
      return .refused(.alert(title: title, message: message))

    case .vetoed(let message, _): return .refused(.removalVetoed(id: id, message: message))
    case .stopped, nil: break
    }
    guard workspace.worktree(worktree.id) == nil else {
      return .refused(.worktreeNotRemoved(id: id))
    }
    return .done
  }

  /// The menu's Auto Rename, answered once it starts; `sidebar list` says
  /// while it runs and why it left the name, as the row does.
  func replyToAutoRenameWorktree(_ id: String) -> ControlReply {
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    guard canAutoRename(worktree) else { return .refused(.autoRenameUnavailable(id: id)) }
    autoRename(worktree)
    return .done
  }

  /// A click on the row.
  func replyToSelectWorktree(_ id: String) -> ControlReply {
    guard let worktree = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    guard select(worktree) else { return .refused(.worktreeNotReady(id: id)) }
    return .done
  }
}

import Foundation
import MultishellCore

extension AppModel {
  /// Opens the sheet for `project`, or the one being worked in. With several
  /// projects and nothing selected the picker starts blank.
  public func requestNewWorktree(in project: Project? = nil) {
    newWorktreeRequest = NewWorktreeRequest(projectID: (project ?? projectInView)?.id)
  }

  /// What git refuses to check out a second time in the draft's project, none
  /// while no project is chosen.
  public func checkedOutBranches(for draft: NewWorktreeDraft) -> Set<String> {
    draft.projectID.map { workspace.checkedOutBranches(of: $0) } ?? []
  }

  /// The draft's project's effective prefix, shown as fixed text so the user
  /// types only the part that varies.
  public func branchPrefix(for draft: NewWorktreeDraft) -> String {
    draft.projectID.flatMap(workspace.project).map {
      effectiveWorktreeSettings(for: $0).branchPrefix
    } ?? ""
  }

  /// Where the sheet's draft would put its worktree, or a dash while there
  /// is no project or no name to place.
  public func plannedLocation(for draft: NewWorktreeDraft) -> String {
    let name = draft.trimmedBranch
    guard let project = draft.projectID.flatMap(workspace.project), !name.isEmpty,
      let url = plannedPath(forBranch: name, createsBranch: draft.createsBranch, in: project)
    else { return "\u{2014}" }
    return url.path.abbreviatingHomeDirectory()
  }

  /// The sheet's agent rows as the draft's project has them, its own file
  /// and overrides counted; off while no project is chosen.
  public func fitAgent(of draft: inout NewWorktreeDraft) {
    let project = draft.projectID.flatMap(workspace.project).map(effectiveProject)
    draft.fitAgent(
      startsByDefault: project.map(workspace.autoStartsAgentOnCreate) ?? false,
      preferred: project.flatMap(workspace.effectiveAgentID), offered: newTabAgentIDs)
  }

  /// The sheet's reads, `nil` once the task asking is cancelled: a project
  /// switch cancels it but not the call inside, so each step checks.
  public func newWorktreeBranches(of project: Project) async -> NewWorktreeBranches? {
    let hasCommits = await hasCommits(project)
    guard !Task.isCancelled else { return nil }
    let (local, remote) = await branches(of: project)
    guard !Task.isCancelled else { return nil }
    let current = await currentBranch(of: project)
    guard !Task.isCancelled else { return nil }
    return NewWorktreeBranches(
      hasCommits: hasCommits, localBranches: local, remoteBranches: remote,
      currentBranch: current)
  }

  private func hasCommits(_ project: Project) async -> Bool {
    await coordinator?.git.hasCommits(project) ?? false
  }

  private func branches(of project: Project) async -> (local: [String], remote: [String]) {
    await coordinator?.git.branchNames(project) ?? ([], [])
  }

  private func currentBranch(of project: Project) async -> String {
    (try? await coordinator?.git.currentBranch(project)) ?? "HEAD"
  }
}

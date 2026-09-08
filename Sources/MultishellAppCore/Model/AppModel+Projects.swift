import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  public func chooseProject() async {
    guard let url = await platform.chooseDirectory(prompt: "Add Project") else { return }
    await addProject(at: url)
  }

  public func addProject(at url: URL) async {
    guard let worktrees else { return }
    guard await worktrees.isRepository(url) else {
      presentedError = .notARepository(url)
      return
    }
    // A subdirectory or a linked worktree is the same repository; adding it
    // as its own project would list the same worktrees twice.
    let root = (try? await worktrees.repositoryRoot(containing: url)) ?? url
    let project = store.addProject(at: root)
    await refresh(project)
    await rearmWatcher()
  }

  /// Entry point from the UI. Always asks: removal closes every live
  /// terminal in the project's worktrees, with no undo.
  public func requestProjectRemoval(_ project: Project, from source: PendingProjectRemoval.Source) {
    pendingProjectRemoval = PendingProjectRemoval(project: project, source: source)
  }

  /// What the confirmation says, with the live terminal count.
  public func projectRemovalMessage(for project: Project) -> String {
    let live = workspace.worktrees(of: project.id).map { liveTerminalCount(in: $0.id) }
    return PendingProjectRemoval.message(liveTerminals: live.reduce(0, +))
  }

  public func removeProject(_ project: Project) {
    forgetMergeStates(of: project.id)
    // Not part of `forgetMergeStates`: that also runs for a project whose
    // default branch went away, which must keep its commit dates. Cleared
    // here so re-adding the project does not order its rows by dates read
    // before it left; paths are ids, so the entries would still match.
    for worktree in workspace.worktrees(of: project.id) { lastCommits[worktree.id] = nil }
    mergeBases[project.id] = nil
    commonGitDirectories[project.id] = nil
    worktreeRecords[project.id] = nil
    sharedSettings[project.id] = nil
    sharedSettingsStamps[project.id] = nil
    sharedSettingsProblems[project.id] = nil
    if pendingSharedHooksTrust?.projectID == project.id { pendingSharedHooksTrust = nil }
    store.removeProject(project.id)
    sync()
    Task { await rearmWatcher() }
  }

  /// Moves `id` to sit just above or just below `target`.
  public func moveProject(_ id: Project.ID, _ placement: ProjectPlacement, _ target: Project.ID) {
    let projects = workspace.projects
    guard
      let from = projects.firstIndex(where: { $0.id == id }),
      let anchor = projects.firstIndex(where: { $0.id == target }),
      from != anchor
    else { return }
    let destination = placement == .above ? anchor : anchor + 1
    store.moveProjects(from: IndexSet(integer: from), to: destination)
  }

  public func setExpanded(_ expanded: Bool, for project: Project) {
    store.setExpanded(expanded, forProject: project.id)
  }

  public func updateSettings(_ settings: ProjectSettings, for project: Project) {
    store.updateSettings(settings, forProject: project.id)
  }

  /// Refresh chosen by the user. A failure already shown for this project is
  /// shown again: the click asked for an answer.
  public func refreshRequested(_ project: Project) async {
    missingProjects.remove(project.id)
    await refresh(project)
  }

  public func refresh(_ project: Project) async {
    guard let worktrees else { return }
    let path = project.path
    guard await Self.offMain({ FileManager.default.fileExists(atPath: path.path) }) else {
      missingProjects.insert(project.id)
      return
    }
    // Read before the list so a change landing in between is caught by the
    // next tick rather than lost.
    var records: WorktreeRecords?
    if let common = await commonGitDirectory(of: project) {
      records = await Self.offMain { WorktreeRecords.read(commonDirectory: common) }
    }
    let shared = await Self.offMain { Self.readSharedSettings(from: path) }
    do {
      let discovered = try await worktrees.refresh(project)
      // Removed while git ran: the store ignores the list, and the records
      // and directory cached above must not come back for it either.
      guard workspace.project(project.id) != nil else {
        commonGitDirectories[project.id] = nil
        return
      }
      store.replaceWorktrees(discovered, forProject: project.id)
      // A worktree removed here or by hand takes its half-finished rename
      // with it; a stale id would otherwise open a field unbidden if git
      // ever listed that path again.
      if let renaming = renamingWorktreeID, workspace.worktree(renaming) == nil {
        renamingWorktreeID = nil
      }
      worktreeRecords[project.id] = records
      missingProjects.remove(project.id)
      noteSharedSettings(shared.result, stamp: shared.stamp, for: project)
    } catch {
      // Every watcher tick and every return to the foreground refreshes a
      // project git cannot read, so the alert goes up on the first failure
      // only; the row stays dimmed until a refresh succeeds.
      if missingProjects.insert(project.id).inserted { report(error) }
    }
  }
}

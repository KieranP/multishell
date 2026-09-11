import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  public func chooseProject() async {
    guard let url = await platform.chooseDirectory(prompt: t("action.add-project")) else { return }
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
    // A file list or hook still running here is ended by signal, as the
    // pane's Cancel ends it: the project has just been told to go.
    for worktree in workspace.worktrees(of: project.id) {
      cancelStage(of: worktree)
      worktreeOperations.clear(worktree.id)
      // A half-finished rename goes with its row: no refresh runs for a
      // project that has left, and re-adding it would open the field.
      if renamingWorktreeID == worktree.id { renamingWorktreeID = nil }
    }
    forgetMergeStates(of: project.id)
    // Not in `forgetMergeStates`, which also runs for a project whose trunk
    // went away and must keep its dates. Paths are ids, so these would match.
    for worktree in workspace.worktrees(of: project.id) { lastCommits[worktree.id] = nil }
    mergeBases[project.id] = nil
    // Or a project re-added while git still cannot read it would be dimmed
    // with no alert: the first failure is what reports one.
    missingProjects.remove(project.id)
    commonGitDirectories[project.id] = nil
    worktreeRecords[project.id] = nil
    sharedSettings.forget(project.id)
    if pendingSharedHooksTrust?.projectID == project.id { pendingSharedHooksTrust = nil }
    // Or the settings window's fallback to the current project never fires:
    // a stale id wins over it, and the window opens only to dismiss itself.
    if settingsProjectID == project.id { settingsProjectID = nil }
    // The dialogs this project's windows left standing, the settings window
    // being its own scene. A stale sheet's Create would add a real worktree.
    if newWorktreeRequest?.projectID == project.id { newWorktreeRequest = nil }
    if pendingRemoval?.worktree.projectID == project.id { pendingRemoval = nil }
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
      forgetVanishedWorktrees()
      // A removed worktree takes its half-finished rename with it, a stale
      // id opening a field if git ever lists that path again.
      if let renaming = renamingWorktreeID, workspace.worktree(renaming) == nil {
        renamingWorktreeID = nil
      }
      worktreeRecords[project.id] = records
      missingProjects.remove(project.id)
      noteSharedSettings(shared.result, stamp: shared.stamp, for: project)
      // A worktree removed outside the app loses its tabs and sessions here,
      // and without this the host keeps their surfaces and the shells run on.
      reconcileSessions()
    } catch {
      // Every tick and every return to the front refreshes a project git
      // cannot read, so the alert goes up once; the row stays dimmed.
      if missingProjects.insert(project.id).inserted { report(error) }
    }
  }
}

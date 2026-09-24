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
    mergeBases[project.id] = nil
    // Or a project re-added while git still cannot read it would be dimmed
    // with no alert: the first failure is what reports one.
    missingProjects.remove(project.id)
    commonGitDirectories[project.id] = nil
    worktreeRecords[project.id] = nil
    worktreeOrders.forget(project.id)
    if pendingSharedSettingsTrust?.projectID == project.id { pendingSharedSettingsTrust = nil }
    // Or the settings window's fallback to the current project never fires:
    // a stale id wins over it, and the window opens only to dismiss itself.
    if settingsProjectID == project.id { settingsProjectID = nil }
    // The sheet this project's windows left standing, the settings window
    // being its own scene. A stale sheet's Create would add a real worktree.
    if newWorktreeRequest?.projectID == project.id { newWorktreeRequest = nil }
    forgetWorktrees(store.removeProject(project.id))
    reconcileSessions(takingFocus: true)
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
    store.moveProject(at: from, to: destination)
  }

  public func setExpanded(_ expanded: Bool, for project: Project) {
    store.setExpanded(expanded, forProject: project.id)
    // A collapsed project's rows went unread; opening reads them now, through
    // the poll's own read, which holds git to a few at a time.
    guard expanded else { return }
    Task { await refreshStatuses(of: project.id) }
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
      if workspace.project(project.id) != nil { missingProjects.insert(project.id) }
      return
    }
    // Read before the list so a change landing in between is caught by the
    // next tick rather than lost.
    var records: WorktreeRecords?
    if let common = await commonGitDirectory(of: project) {
      records = await Self.offMain { WorktreeRecords.read(commonDirectory: common) }
    }
    let shared = await Self.offMain { Self.readSharedSettings(of: project) }
    do {
      let discovered = try await worktrees.refresh(project)
      // Removed while git ran: the store ignores the list, and the records
      // and directory cached above must not come back for it either.
      guard workspace.project(project.id) != nil else {
        commonGitDirectories[project.id] = nil
        return
      }
      forgetWorktrees(store.replaceWorktrees(discovered, forProject: project.id))
      worktreeRecords[project.id] = records
      missingProjects.remove(project.id)
      noteSharedSettings(shared, for: project)
      // A worktree removed outside the app loses its tabs and sessions here,
      // and without this the host keeps their surfaces and the shells run on.
      reconcileSessions(takingFocus: false)
    } catch {
      // Removed while git ran: the same as above, and nothing to dim.
      guard workspace.project(project.id) != nil else {
        commonGitDirectories[project.id] = nil
        return
      }
      // Every tick and every return to the front refreshes a project git
      // cannot read, so the alert goes up once; the row stays dimmed.
      if missingProjects.insert(project.id).inserted { report(error) }
    }
  }
}

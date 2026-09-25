import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// The project a worktree-scoped command should act on: the selected
  /// worktree's project, or the only project when nothing is selected yet.
  public var selectedProject: Project? {
    if let worktree = workspace.selectedWorktree {
      return workspace.project(worktree.projectID)
    }
    return workspace.projects.count == 1 ? workspace.projects.first : nil
  }

  /// The project a command should act on while nothing else names one: the
  /// worktree in view's, or the only project. The board names none.
  var projectInView: Project? {
    if let worktree = worktreeInView { return workspace.project(worktree.projectID) }
    return workspace.projects.count == 1 ? workspace.projects.first : nil
  }

  public func chooseProject() async {
    guard let url = await platform.chooseDirectory(prompt: t("action.add-project")) else { return }
    await addProject(at: url)
  }

  func addProject(at url: URL) async {
    guard let worktrees else { return }
    guard await worktrees.git.isRepository(url) else {
      presentedError = .notARepository(url)
      return
    }
    // A subdirectory or a linked worktree is the same repository; adding it
    // as its own project would list the same worktrees twice.
    let root = (try? await worktrees.git.mainWorktree(containing: url)) ?? url
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
    worktreeOrderMemo.forget(project.id)
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
}

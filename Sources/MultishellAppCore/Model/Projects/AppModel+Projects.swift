import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// The project a command should act on while nothing else names one: the
  /// worktree in view's, or the only project. The board names none.
  var projectInView: Project? { project(of: worktreeInView) }

  func project(of worktree: Worktree?) -> Project? {
    if let worktree { return workspace.project(worktree.projectID) }
    return workspace.projects.count == 1 ? workspace.projects.first : nil
  }

  /// The workspace's copy, or `project` once it has gone: a caller's copy can
  /// predate a write it would then undo.
  func currentCopy(of project: Project) -> Project {
    workspace.project(project.id) ?? project
  }

  public func addProjectFromPicker() async {
    guard let url = await platform.chooseDirectory(prompt: t("action.add-project")) else { return }
    await addProject(at: url)
  }

  func addProject(at url: URL) async {
    guard let coordinator else { return }
    guard await coordinator.git.isRepository(url) else {
      presentedError = .notARepository(url)
      return
    }
    // A subdirectory or a linked worktree is the same repository; adding it
    // as its own project would list the same worktrees twice.
    let root = (try? await coordinator.git.mainWorktree(containing: url)) ?? url
    let project = store.addProject(at: root)
    await refreshWorktrees(of: project)
    await rearmWatcher()
  }

  func setExpanded(_ expanded: Bool, for project: Project) {
    store.setExpanded(expanded, forProject: project.id)
    // A collapsed project's rows went unread; opening reads them now, through
    // the poll's own read, which holds git to a few at a time.
    guard expanded else { return }
    Task { await refreshStatuses(inProject: project.id) }
  }

  public func setSettings(_ settings: ProjectSettings, for project: Project) {
    store.setSettings(settings, forProject: project.id)
  }
}

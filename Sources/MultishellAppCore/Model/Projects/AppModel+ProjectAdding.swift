import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
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
    let root = (try? await coordinator.git.mainWorktreePath(containing: url)) ?? url
    let project = store.addProject(at: root)
    await refreshWorktrees(of: project)
    await rearmWatcher()
  }
}

import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Every project's git directory and every worktree's directory, armed
  /// again wherever a list changes them, whatever read the list. The themes
  /// folder rides on the same stream, so a saved theme is drawn at once.
  func rearmWatcher(evenIfUnchanged: Bool = false) async {
    watcherRearms += 1
    let rearm = watcherRearms
    // A re-arm begun after this one makes it arm nothing; forgetting what is
    // armed makes that later one arm its list, even one with no project.
    if evenIfUnchanged { armedDirectories = nil }
    var directories = [themesDirectory]
    for project in workspace.projects {
      if let common = await commonGitDirectory(of: project) { directories.append(common) }
      directories += workspace.worktrees(of: project.id).map(\.path)
    }
    guard evenIfUnchanged || directories != armedDirectories else { return }
    let worktrees = workspace.worktrees.map { (id: $0.id, path: $0.path) }
    let isOnLocalVolume = isOnLocalVolume
    let themesDirectory = themesDirectory
    let onNetworkVolumes = await runOnDispatch {
      // Made here, as the watcher skips a folder not there yet and re-arms
      // only when the list changes, which a new folder does not.
      try? FileManager.default.createDirectory(
        at: themesDirectory,
        withIntermediateDirectories: true,
      )
      return Set(worktrees.filter { !isOnLocalVolume($0.path) }.map(\.id))
    }
    // A later re-arm read a newer list; arming this one would undo it.
    guard rearm == watcherRearms else { return }
    armedDirectories = directories
    worktreesOnNetworkVolumes = onNetworkVolumes
    await watcher.watch(directories)
  }

  func commonGitDirectory(of project: Project) async -> URL? {
    if let cached = commonGitDirectories[project.id] { return cached }
    guard let coordinator, let common = try? await coordinator.git.commonGitDirectory(project)
    else {
      return nil
    }
    commonGitDirectories[project.id] = common
    return common
  }
}

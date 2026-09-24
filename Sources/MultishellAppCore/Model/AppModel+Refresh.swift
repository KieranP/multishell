import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  func refreshAll() async {
    await refreshWorktreesIfRecordsChanged()
    await refreshStatuses()
    await refreshMergeStates()
  }

  /// A watcher tick or a return to the front. The records are compared before
  /// git is spawned; `changed` narrows it to the projects that fired, empty is all.
  func refreshWorktreesIfRecordsChanged(under changed: [URL] = []) async {
    var refreshed = false
    for project in workspace.projects {
      let common = await commonGitDirectory(of: project)
      if !changed.isEmpty {
        guard let common, changed.contains(where: { $0.pathComponents(under: common) != nil })
        else { continue }
      }
      if let common, let known = worktreeRecords[project.id],
        await Self.offMain({ WorktreeRecords.read(commonDirectory: common) }) == known
      {
        await refreshSharedSettingsIfChanged(project)
        continue
      }
      await refresh(project)
      refreshed = true
    }
    if refreshed { await rearmWatcher() }
  }

  /// Re-read after every refresh: a new worktree adds a directory that must
  /// itself be watched for branch changes.
  func rearmWatcher() async {
    var directories: [URL] = []
    for project in workspace.projects {
      guard let common = await commonGitDirectory(of: project) else { continue }
      directories += await Self.offMain { WorktreeCoordinator.directoriesToWatch(in: common) }
    }
    await watcher.watch(directories)
  }

  func commonGitDirectory(of project: Project) async -> URL? {
    if let cached = commonGitDirectories[project.id] { return cached }
    guard let worktrees, let common = try? await worktrees.commonGitDirectory(project) else {
      return nil
    }
    commonGitDirectories[project.id] = common
    return common
  }
}

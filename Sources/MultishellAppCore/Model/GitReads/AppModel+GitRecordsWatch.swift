import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Re-read after every refresh: a new worktree adds a directory that must
  /// itself be watched for branch changes.
  func rearmWatcher() async {
    var directories: [URL] = []
    for project in workspace.projects {
      guard let common = await commonGitDirectory(of: project) else { continue }
      directories += await runOnDispatch { WorktreeRecords.directoriesToWatch(in: common) }
    }
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

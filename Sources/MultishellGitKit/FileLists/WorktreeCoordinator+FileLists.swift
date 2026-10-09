import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeCoordinator {
  /// Links or copies the project's listed files in before the post-create
  /// hook, so the hook and the first terminal both find them.
  public func placeFiles(
    _ list: WorktreeFileList,
    for project: Project,
    into worktreePath: URL,
    stopper: ProcessStopper?,
  ) throws -> [String] {
    try WorktreeFiles.place(
      list.listText,
      as: list.placement,
      from: project.path,
      to: worktreePath,
      isRepositoryList: list.isRepositoryList,
      isStopRequested: { stopper?.isStopRequested == true },
    )
  }
}

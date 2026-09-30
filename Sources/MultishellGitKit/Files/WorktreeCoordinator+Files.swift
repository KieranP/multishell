import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeCoordinator {
  /// Links or copies the project's listed files in before the post-create
  /// hook, so the hook and the first terminal both find them.
  @discardableResult
  public func placeFiles(
    _ list: WorktreeFileList, for project: Project, into worktreePath: URL,
    stopper: ProcessStopper? = nil
  ) throws -> [String] {
    try WorktreeFiles.place(
      list.listText, as: list.placement, from: project.path, to: worktreePath,
      heldToRepository: list.heldToRepository, isStopped: { stopper?.isStopRequested == true })
  }
}

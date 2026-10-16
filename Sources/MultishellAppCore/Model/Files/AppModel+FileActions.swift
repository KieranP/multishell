import Foundation
import MultishellCore

/// Open in Editor, Reveal in Finder and Copy Path on one of a worktree's files
/// or folders, which the Files panel's rows and a file tab's menu both offer.
extension AppModel {
  public func openInEditor(path: String, in worktreeID: Worktree.ID) {
    guard let worktree = workspace.worktree(worktreeID) else { return }
    openInEditor(file: worktree.path.appending(path: path), in: worktree)
  }

  public func revealInFileBrowser(path: String, in worktreeID: Worktree.ID) {
    guard let worktree = workspace.worktree(worktreeID) else { return }
    platform.revealInFileBrowser(worktree.path.appending(path: path))
  }

  /// The absolute path, as the worktree's own Copy Path copies.
  public func copyPath(_ path: String, in worktreeID: Worktree.ID) {
    guard let worktree = workspace.worktree(worktreeID) else { return }
    platform.copyToClipboard(worktree.path.appending(path: path).path)
  }
}

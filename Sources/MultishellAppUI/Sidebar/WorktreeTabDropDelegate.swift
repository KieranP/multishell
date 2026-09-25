import MultishellAppCore
import MultishellCore
import SwiftUI

/// A tab dropped on a worktree's row. Not `dropDestination`: its payload can
/// load after the drag session's end, which has put the tab back by then.
struct WorktreeTabDropDelegate: DropDelegate {
  let worktreeID: Worktree.ID
  @Binding var target: Worktree.ID?
  /// `false` where a release would not move the tab, so the row neither
  /// lights nor offers a move.
  let takes: (Worktree.ID) -> Bool
  /// `false` leaves the drag open, and its session's end puts the tab back.
  let drop: (Worktree.ID) -> Bool

  func validateDrop(info: DropInfo) -> Bool { info.carriesATab }

  func dropEntered(info: DropInfo) {
    if takes(worktreeID) { target = worktreeID }
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: takes(worktreeID) ? .move : .forbidden)
  }

  func dropExited(info: DropInfo) {
    if target == worktreeID { target = nil }
  }

  func performDrop(info: DropInfo) -> Bool {
    target = nil
    return drop(worktreeID)
  }
}

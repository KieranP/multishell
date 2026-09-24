import Foundation
import MultishellCore

/// How much of a worktree's git badge a row has room for, widest first. The
/// file count goes first, then the arrows; the tooltip names them all.
public enum ChangeBadgeDetail: CaseIterable, Sendable {
  case full
  case withoutFiles
  case essentials

  public func showsFiles(of status: WorktreeStatus) -> Bool {
    self == .full && status.unscoredFiles > 0
  }

  /// A badge that is only arrows keeps them, or there would be no badge.
  public func showsArrows(of status: WorktreeStatus) -> Bool {
    self != .essentials || !status.isDirty
  }
}

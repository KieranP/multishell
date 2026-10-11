import Foundation
import MultishellCore

/// What `multishell debug notifications` prints: the Dock badge and the
/// banners posted, oldest first, each still up or taken back.
struct DebugNotificationRecord: Encodable, Equatable {
  struct Banner: Encodable, Equatable {
    let title: String
    let body: String
    /// The pane it is about, or for a report naming only a directory, the
    /// worktree's `ControlID`.
    let pane: TerminalSession.ID?
    let worktree: String?
    let postedAt: Date
    /// Not yet taken back, its pane still saying what it said.
    let isStanding: Bool
  }

  /// `nil` for no badge.
  let badge: Int?
  let banners: [Banner]
}

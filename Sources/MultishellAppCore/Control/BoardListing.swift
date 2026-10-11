import Foundation
import MultishellCore

/// What `multishell board list` prints: the board's columns, most urgent
/// first, and their cards in the order it draws them.
struct BoardListing: Encodable, Equatable {
  struct Column: Encodable, Equatable {
    let lane: String
    let cards: [Card]
  }

  struct Card: Encodable, Equatable {
    let pane: TerminalSession.ID
    let tab: TerminalTab.ID
    /// Its worktree's `ControlID`.
    let worktree: String
    let title: String
    /// The catalogue id, `nil` for a shell.
    let agent: String?
    /// Its project's `ControlID`, `nil` once the worktree has gone.
    let project: String?
    let projectName: String
    let worktreeName: String
    let state: SessionState?
    let workerCount: Int
  }

  let showsAllTerminals: Bool
  let columns: [Column]
}

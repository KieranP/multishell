import Foundation
import MultishellCore

/// One pane row under the worktree in view, as the row draws it.
public struct SidebarPane: Identifiable, Equatable, Sendable {
  public let id: TerminalSession.ID
  public let title: String
  public let position: PanePosition?
  public let isFocused: Bool
  public let state: SessionState?
  /// When the pane entered `state`, as a board card's.
  let since: Date?
  public let workers: [Worker]
  public let agentID: String?
  let agentName: String?
  /// Runs a project action, drawn with the play mark rather than the terminal's.
  public internal(set) var isAction = false
}

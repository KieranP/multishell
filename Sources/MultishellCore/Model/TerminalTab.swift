import Foundation

/// One tab in a worktree's terminal pane.
///
/// A tab owns a pane tree rather than a single terminal, so splits are a
/// change to `root` rather than a change to this type.
public struct TerminalTab: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var worktreeID: Worktree.ID
  public var root: PaneNode
  public var focusedSessionID: TerminalSession.ID
  /// Set by the user. While present it wins over whatever the shell reports
  /// through OSC; clearing it hands the title back to the shell.
  public var customTitle: String?

  public init(
    id: UUID = UUID(), worktreeID: Worktree.ID, root: PaneNode, focusedSessionID: TerminalSession.ID
  ) {
    self.id = id
    self.worktreeID = worktreeID
    self.root = root
    self.focusedSessionID = focusedSessionID
  }

  public init(id: UUID = UUID(), worktreeID: Worktree.ID, session: TerminalSession.ID) {
    self.init(id: id, worktreeID: worktreeID, root: .terminal(session), focusedSessionID: session)
  }

  public var sessionIDs: [TerminalSession.ID] { root.sessionIDs }
  public var isSplit: Bool { !root.isLeaf }
}

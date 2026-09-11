import Foundation

/// One tab in a worktree's terminal pane, owning a pane tree and naming its
/// column. The worktree sits beside it, deciding where its shells start.
public struct TerminalTab: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var worktreeID: Worktree.ID
  /// The column this tab's strip is part of; see `TabGroup`.
  public var groupID: TabGroup.ID
  public var root: PaneNode
  public var focusedSessionID: TerminalSession.ID
  /// Set by the user. While present it wins over whatever the shell reports
  /// through OSC; clearing it hands the title back to the shell.
  public var customTitle: String?

  public init(
    id: UUID = UUID(),
    worktreeID: Worktree.ID,
    groupID: TabGroup.ID,
    root: PaneNode,
    focusedSessionID: TerminalSession.ID
  ) {
    self.id = id
    self.worktreeID = worktreeID
    self.groupID = groupID
    self.root = root
    self.focusedSessionID = focusedSessionID
  }

  public init(
    id: UUID = UUID(), worktreeID: Worktree.ID, groupID: TabGroup.ID, session: TerminalSession.ID
  ) {
    self.init(
      id: id, worktreeID: worktreeID, groupID: groupID, root: .terminal(session),
      focusedSessionID: session)
  }

  /// Everything but the group is required, a tab with no tree being no tab.
  /// A tab with no group is one saved before columns existed.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.worktreeID = try container.decode(Worktree.ID.self, forKey: .worktreeID)
    self.groupID = container.decodeTolerantly(
      TabGroup.ID.self, forKey: .groupID, or: TabGroup.unassigned)
    self.root = try container.decode(PaneNode.self, forKey: .root)
    self.focusedSessionID = try container.decode(
      TerminalSession.ID.self, forKey: .focusedSessionID)
    self.customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle)
  }

  public var sessionIDs: [TerminalSession.ID] { root.sessionIDs }
  public var isSplit: Bool { !root.isLeaf }
}

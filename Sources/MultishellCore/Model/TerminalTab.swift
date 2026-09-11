import Foundation

/// One tab in a worktree's terminal pane.
///
/// A tab owns a pane tree rather than a single terminal, so splits are a
/// change to `root` rather than a change to this type. It also names the
/// column it sits in: the worktree is kept beside it rather than read
/// through the group, because it is what decides where the tab's shells
/// start and which shell they run, and a tab dragged to another worktree
/// changes both at once.
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

  /// Everything but the group is required, as it was before groups existed:
  /// a tab with no tree is not a tab, and tabs decode element by element so
  /// a broken one costs itself alone. A tab with no group is what every tab
  /// in a state file written before this feature looks like, and
  /// `Workspace.adoptUngroupedTabs` gives each worktree's tabs the one
  /// column they were saved as.
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

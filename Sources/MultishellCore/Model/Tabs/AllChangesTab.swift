import Foundation

/// A read-only tab showing every change in its worktree as one diff, at most
/// one per worktree; see Docs/design/files/all-changes-tab.md.
public struct AllChangesTab: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public let worktreeID: Worktree.ID
  /// The group this tab's strip is part of; see `TabGroup`.
  public internal(set) var groupID: TabGroup.ID
  /// Written at quit, as a file tab's is.
  public internal(set) var scroll: AllChangesScroll?

  init(worktreeID: Worktree.ID, groupID: TabGroup.ID) {
    self.id = UUID()
    self.worktreeID = worktreeID
    self.groupID = groupID
  }

  /// The group is tolerated as a file tab's is, the repair finding it one.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.worktreeID = try container.decode(Worktree.ID.self, forKey: .worktreeID)
    self.groupID = container.decodeTolerantly(
      TabGroup.ID.self,
      forKey: .groupID,
      or: TabGroup.unassigned,
    )
    self.scroll = try? container.decodeIfPresent(AllChangesScroll.self, forKey: .scroll)
  }
}

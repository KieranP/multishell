import Foundation

/// One group of tabs in a worktree's terminal area, left to right in
/// `Workspace.tabGroups`; see Docs/design/tabs-and-groups.md.
public struct TabGroup: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var worktreeID: Worktree.ID
  /// Share of the worktree's width, relative to the other groups' rather
  /// than a fraction, so a removal needs no renormalising.
  public var weight: Double
  /// The tab this group shows. Never `nil` for a group the store kept: a
  /// group whose last tab left is removed rather than left standing empty.
  public var shownTabID: TerminalTab.ID?

  /// The group id a tab written before groups existed carries.
  /// `Workspace.adoptUngroupedTabs` resolves every one into a real group.
  static let unassigned = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

  init(
    id: UUID = UUID(),
    worktreeID: Worktree.ID,
    weight: Double = 1,
    shownTabID: TerminalTab.ID? = nil
  ) {
    self.id = id
    self.worktreeID = worktreeID
    self.weight = LayoutWeight.usable(weight)
    self.shownTabID = shownTabID
  }

  /// `shownTabID` keeps the key it was saved under; see state-and-store.md.
  enum CodingKeys: String, CodingKey {
    case id, worktreeID, weight
    case shownTabID = "activeTabID"
  }

  /// Weight and shown tab default; id and worktree do not, a group
  /// belonging to nothing being no group. Costs that group alone.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.worktreeID = try container.decode(Worktree.ID.self, forKey: .worktreeID)
    self.weight = LayoutWeight.usable(
      container.decodeTolerantly(Double.self, forKey: .weight, or: 1))
    self.shownTabID = container.decodeTolerantly(TerminalTab.ID.self, forKey: .shownTabID)
  }
}

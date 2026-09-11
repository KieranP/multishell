import Foundation

/// One column of tabs in a worktree's terminal area, left to right in
/// `Workspace.tabGroups`; see docs/design/tabs-and-columns.md.
public struct TabGroup: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var worktreeID: Worktree.ID
  /// Share of the worktree's width, relative to the other groups' rather
  /// than a fraction, so a removal needs no renormalising.
  public var weight: Double
  /// The tab this column shows. Never `nil` for a group the store kept: a
  /// group whose last tab left is removed rather than left standing empty.
  public var activeTabID: TerminalTab.ID?

  /// The group id a tab written before groups existed carries.
  /// `Workspace.adoptUngroupedTabs` resolves every one into a real group.
  public static let unassigned = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

  public init(
    id: UUID = UUID(),
    worktreeID: Worktree.ID,
    weight: Double = 1,
    activeTabID: TerminalTab.ID? = nil
  ) {
    self.id = id
    self.worktreeID = worktreeID
    self.weight = Self.usableWeight(weight)
    self.activeTabID = activeTabID
  }

  /// A weight of zero, or one that is not a number, is a column nothing can
  /// be laid out in; `PaneNode` makes the same substitution for a split's.
  static func usableWeight(_ weight: Double) -> Double {
    weight.isFinite && weight > 0 ? weight : 1
  }

  /// Weight and active tab default; id and worktree do not, a group
  /// belonging to nothing being no column. Costs that group alone.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.worktreeID = try container.decode(Worktree.ID.self, forKey: .worktreeID)
    self.weight = Self.usableWeight(container.decodeTolerantly(Double.self, forKey: .weight, or: 1))
    self.activeTabID = container.decodeTolerantly(TerminalTab.ID.self, forKey: .activeTabID)
  }
}

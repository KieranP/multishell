import Foundation

/// One column of tabs in a worktree's terminal area.
///
/// Groups sit side by side and never one above another: a tab that wants a
/// pane below it splits, which is what `PaneNode` is for. Order in
/// `Workspace.tabGroups` is left-to-right order, and a group is a record of
/// its own rather than a field on `TerminalTab` because a column outlives
/// the tabs that pass through it: its width and which tab it shows have to
/// survive the last tab moving out of it and a new one moving in.
///
/// Unlike a worktree, whose identity is its path because git hands the list
/// back on every refresh, nothing rediscovers a group, so it carries a
/// generated id and holds its own `activeTabID`.
public struct TabGroup: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var worktreeID: Worktree.ID
  /// Share of the worktree's width, read the way a split's weights are:
  /// relative to the other groups' rather than a fraction. So a group
  /// removed leaves the rest in proportion with nothing to renormalise.
  public var weight: Double
  /// The tab this column shows. Never `nil` for a group the store kept: a
  /// group whose last tab left is removed rather than left standing empty.
  public var activeTabID: TerminalTab.ID?

  /// The group id a tab written before groups existed carries.
  /// `Workspace.adoptUngroupedTabs` resolves every one of these into a real
  /// group, so it never reaches the store or a view.
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

  /// The weight and the active tab both default, so a group written by a
  /// build that did not have them still loads. The id and the worktree do
  /// not: a group belonging to nothing is not a column, and groups decode
  /// element by element, so it costs that group alone.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.worktreeID = try container.decode(Worktree.ID.self, forKey: .worktreeID)
    let weight = (try? container.decodeIfPresent(Double.self, forKey: .weight)) ?? nil
    self.weight = Self.usableWeight(weight ?? 1)
    self.activeTabID =
      (try? container.decodeIfPresent(TerminalTab.ID.self, forKey: .activeTabID)) ?? nil
  }
}

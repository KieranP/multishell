import Foundation

/// One group of tabs in a worktree's terminal area, left to right in
/// `Workspace.tabGroups`; see Docs/design/tabs-and-groups.md.
public struct TabGroup: Identifiable, Codable, Hashable, Sendable {
  /// `shownTabID` keeps the key it was saved under; see state-and-store.md.
  enum CodingKeys: String, CodingKey {
    case id, worktreeID, weight, tabOrder
    case shownTabID = "activeTabID"
  }

  /// The group id a tab written before groups existed carries.
  /// `Workspace.adoptUngroupedTabs` resolves every one into a real group.
  static let unassigned = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

  public let id: UUID
  public internal(set) var worktreeID: Worktree.ID
  /// Share of the worktree's width, relative to the other groups' rather
  /// than a fraction, so a removal needs no renormalising.
  public internal(set) var weight: Double
  /// The tab this group shows, of either kind. Never `nil` for a group the
  /// store kept: a group whose last tab left is removed rather than left empty.
  public internal(set) var shownTabID: WorkspaceTab.ID?
  /// Every tab in the group, terminal and file, left to right. An older build
  /// reads strip order from `Workspace.tabs`, which the store keeps in step.
  var tabOrder: [WorkspaceTab.ID]

  init(
    worktreeID: Worktree.ID,
    weight: Double = 1,
    shownTabID: WorkspaceTab.ID? = nil,
  ) {
    self.id = UUID()
    self.worktreeID = worktreeID
    self.weight = LayoutWeight.usable(weight)
    self.shownTabID = shownTabID
    self.tabOrder = []
  }

  /// Weight and shown tab default; id and worktree do not, a group
  /// belonging to nothing being no group. Costs that group alone.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.worktreeID = try container.decode(Worktree.ID.self, forKey: .worktreeID)
    self.weight = LayoutWeight.usable(
      container.decodeTolerantly(Double.self, forKey: .weight, or: 1)
    )
    self.shownTabID = container.decodeTolerantly(WorkspaceTab.ID.self, forKey: .shownTabID)
    // Missing from a file an older build wrote; `repair` fills it from the tabs.
    self.tabOrder = container.decodeTolerantly([WorkspaceTab.ID].self, forKey: .tabOrder, or: [])
  }
}

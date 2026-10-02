import MultishellCore

/// Where a dragged tab would make a group: beside this one, on this side.
public struct TabGroupBand: Equatable, Sendable {
  let groupID: TabGroup.ID
  let placement: TerminalTab.Placement

  public init(groupID: TabGroup.ID, placement: TerminalTab.Placement) {
    self.groupID = groupID
    self.placement = placement
  }
}

import MultishellCore

/// The project block a dragged project hovers over, and which side of it the
/// insertion line is drawn on.
public struct ProjectDropTarget: Equatable, Sendable {
  public let projectID: Project.ID
  public let placement: ProjectPlacement

  public init(projectID: Project.ID, placement: ProjectPlacement) {
    self.projectID = projectID
    self.placement = placement
  }
}

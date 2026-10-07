import MultishellCore

/// The project block a dragged project hovers over, and which side of it the
/// insertion line is drawn on.
public struct ProjectInsertion: Equatable, Sendable {
  public let projectID: Project.ID
  let placement: ProjectPlacement

  public init(projectID: Project.ID, placement: ProjectPlacement) {
    self.projectID = projectID
    self.placement = placement
  }

  /// The side of this block the insertion line goes, `nil` for none: a
  /// target outlives a drag that ended without a drop.
  public func insertionPlacement(on id: Project.ID, isDragging: Bool) -> ProjectPlacement? {
    isDragging && projectID == id ? placement : nil
  }
}

import Foundation
import MultishellCore

/// The New Worktree sheet, asked for. The project may be unknown, the sheet
/// then opening with its picker blank.
public struct NewWorktreeRequest: Identifiable, Sendable {
  public let id = UUID()
  public let projectID: Project.ID?

  public init(projectID: Project.ID?) {
    self.projectID = projectID
  }
}

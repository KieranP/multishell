import Foundation
import MultishellCore

/// The New Worktree sheet, asked for. The project may be unknown: the menu
/// item with several projects and nothing selected used to do nothing, and
/// now opens the sheet with its project picker blank.
struct NewWorktreeRequest: Identifiable {
  let id = UUID()
  let projectID: Project.ID?
}

import Foundation

/// One save, the workspace as a value and where it goes, ready to run on
/// any thread. Its ticket keeps saves landing in the order they were asked.
public struct WorkspaceSave: Sendable {
  let workspace: Workspace
  let snapshot: WorkspaceSnapshot
  let ticket: WorkspaceSnapshot.Ticket

  public func run() throws {
    try snapshot.save(workspace, as: ticket)
  }
}

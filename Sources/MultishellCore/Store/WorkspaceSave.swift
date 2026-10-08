/// One save, the workspace as a value and where it goes, ready to write on
/// any thread. Its ticket keeps saves landing in the order they were asked.
public struct WorkspaceSave: Sendable {
  let workspace: Workspace
  let file: StateFile
  let ticket: SaveOrder.Ticket

  public func write() throws {
    try file.save(workspace, as: ticket)
  }
}

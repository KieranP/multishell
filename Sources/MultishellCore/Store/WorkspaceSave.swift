/// One save, the workspace as a value and where it goes, ready to write on
/// any thread. Its ticket keeps saves landing in the order they were asked.
public struct WorkspaceSave: Sendable {
  let workspace: Workspace
  let file: StateFile
  let ticket: SaveOrder.Ticket

  /// The bytes written, `nil` where a later save landed first.
  @discardableResult
  public func write() throws -> Int? {
    try file.save(workspace, as: ticket)
  }
}

import Foundation

/// Reads and writes a `Workspace` as JSON. Running processes are not
/// persisted; only the sidebar's shape and which tabs should exist.
public struct WorkspaceSnapshot: Sendable {
  private let fileURL: URL
  private let order = SaveOrder()

  public init(fileURL: URL = Paths.stateFile) {
    self.fileURL = fileURL
  }

  public typealias Ticket = SaveOrder.Ticket

  func ticket() -> Ticket {
    order.issue()
  }

  /// A file that will not read or decode is moved aside, never overwritten.
  /// The read is inside the `do` for that; see Docs/design/state-and-store.md.
  public func load() throws -> Workspace {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return Workspace() }
    do {
      return try JSONDecoder().decode(Workspace.self, from: try Data(contentsOf: fileURL))
    } catch {
      // Computed once: the name carries a timestamp, and the error must name
      // the file that was actually written.
      let backup = backupURL
      do {
        try FileManager.default.moveItem(at: fileURL, to: backup)
      } catch let move {
        throw UnmovedState(file: fileURL, underlying: error, move: move)
      }
      throw UnreadableState(backup: backup, underlying: error)
    }
  }

  /// Whether a file stands where `save` would write. Asked after a failed
  /// load, when what is still there is the user's own state.
  var holdsFile: Bool {
    FileManager.default.fileExists(atPath: fileURL.path)
  }

  private var backupURL: URL {
    let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    return fileURL.deletingPathExtension().appendingPathExtension("\(stamp).broken.json")
  }

  public func save(_ workspace: Workspace) throws {
    try save(workspace, as: ticket())
  }

  /// The encode is outside the lock, so two saves encode side by side and
  /// only the writes queue.
  public func save(_ workspace: Workspace, as ticket: Ticket) throws {
    let data = try JSONEncoder.forFile().encode(workspace)
    try order.land(ticket) {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: fileURL, options: .atomic)
    }
  }
}

/// The words the user sees are the catalogue's, built by `PresentedError`;
/// see Docs/design/translation.md.
public struct UnreadableState: Error {
  public let backup: URL
  public let underlying: any Error

  public init(backup: URL, underlying: any Error) {
    self.backup = backup
    self.underlying = underlying
  }
}

/// Unreadable and unmovable both, so it still stands where a save would land.
/// Nothing may write that path; see `WorkspaceStore.refusesToSave`.
public struct UnmovedState: Error {
  public let file: URL
  public let underlying: any Error
  public let move: any Error

  public init(file: URL, underlying: any Error, move: any Error) {
    self.file = file
    self.underlying = underlying
    self.move = move
  }
}

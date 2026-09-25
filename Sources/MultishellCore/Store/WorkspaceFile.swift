import Foundation

/// Reads and writes a `Workspace` as JSON. Running processes are not
/// persisted; only the sidebar's shape and which tabs should exist.
public struct WorkspaceFile: Sendable {
  private let fileURL: URL
  private let order = SaveOrder()

  public init(fileURL: URL = Paths.stateFile) {
    self.fileURL = fileURL
  }

  func ticket() -> SaveOrder.Ticket {
    order.issue()
  }

  /// A file that will not read or decode is moved aside, never overwritten.
  /// The read is inside the `do` for that; see Docs/design/state-and-store.md.
  func load() throws -> Workspace {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return Workspace() }
    do {
      return try JSONDecoder().decode(Workspace.self, from: try Data(contentsOf: fileURL))
    } catch {
      // Computed once: the name carries a timestamp, and the error must name
      // the file that was actually written.
      let backup = backupURL
      do {
        try FileManager.default.moveItem(at: fileURL, to: backup)
      } catch _ {
        // `_` leaves `error` the decode failure, which both errors report.
        throw UnmovableStateFile(file: fileURL, underlying: error)
      }
      throw UnreadableStateFile(backup: backup, underlying: error)
    }
  }

  /// Whether a file stands where `save` would write. Asked after a failed
  /// load, when what is still there is the user's own state.
  var existsOnDisk: Bool {
    FileManager.default.fileExists(atPath: fileURL.path)
  }

  private var backupURL: URL {
    let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    return fileURL.deletingPathExtension().appendingPathExtension("\(stamp).broken.json")
  }

  func save(_ workspace: Workspace) throws {
    try save(workspace, as: ticket())
  }

  /// The encode is outside the lock, so two saves encode side by side and
  /// only the writes queue.
  func save(_ workspace: Workspace, as ticket: SaveOrder.Ticket) throws {
    let data = try JSONEncoder.forFile().encode(workspace)
    try order.land(ticket) {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: fileURL, options: .atomic)
    }
  }
}

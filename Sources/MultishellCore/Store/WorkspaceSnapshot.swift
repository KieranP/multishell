import Foundation

/// Reads and writes a `Workspace` as JSON. Running processes are not
/// persisted; only the sidebar's shape and which tabs should exist.
public struct WorkspaceSnapshot: Sendable {
  private let fileURL: URL
  private let order = SaveOrder()

  public init(fileURL: URL = Paths.stateFile) {
    self.fileURL = fileURL
  }

  /// A place in the order of saves, taken where the workspace is read. A
  /// save whose ticket is older than the last landed is dropped, not written.
  public struct Ticket: Sendable {
    fileprivate let number: Int
  }

  public func ticket() -> Ticket {
    Ticket(number: order.issue())
  }

  /// Writes in order and one at a time, whichever thread runs each; see
  /// docs/design/state-and-store.md.
  private final class SaveOrder: @unchecked Sendable {
    private let lock = NSLock()
    private var issued = 0
    private var landed = 0

    func issue() -> Int {
      lock.withLock {
        issued += 1
        return issued
      }
    }

    func land(_ ticket: Int, _ write: () throws -> Void) throws {
      try lock.withLock {
        guard ticket > landed else { return }
        try write()
        landed = ticket
      }
    }
  }

  /// A file that will not read or decode is moved aside, never overwritten.
  /// The read is inside the `do` for that; see docs/design/state-and-store.md.
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
  public var holdsFile: Bool {
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
    try order.land(ticket.number) {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: fileURL, options: .atomic)
    }
  }
}

public struct UnreadableState: Error, CustomStringConvertible {
  public let backup: URL
  public let underlying: any Error

  public init(backup: URL, underlying: any Error) {
    self.backup = backup
    self.underlying = underlying
  }

  public var description: String {
    "Saved state could not be read and was moved to \(backup.lastPathComponent). \(underlying)"
  }
}

/// Unreadable and unmovable both, so it still stands where a save would land.
/// Nothing may write that path; see `WorkspaceStore.refusesToSave`.
public struct UnmovedState: Error, CustomStringConvertible {
  public let file: URL
  public let underlying: any Error
  public let move: any Error

  public init(file: URL, underlying: any Error, move: any Error) {
    self.file = file
    self.underlying = underlying
    self.move = move
  }

  public var description: String {
    "Saved state could not be read and was left at \(file.path). \(underlying)"
  }
}

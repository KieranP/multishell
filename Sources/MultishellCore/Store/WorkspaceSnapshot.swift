import Foundation

/// Reads and writes a `Workspace` as JSON.
///
/// Running processes are deliberately not persisted; only the shape of the
/// sidebar and which tabs should exist survive a relaunch.
public struct WorkspaceSnapshot: Sendable {
  private let fileURL: URL

  public init(fileURL: URL = Paths.stateFile) {
    self.fileURL = fileURL
  }

  /// A file that exists but will not decode is moved aside, never
  /// overwritten: the next save would otherwise destroy the user's sidebar
  /// to fix a bug in ours.
  public func load() throws -> Workspace {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return Workspace() }
    let data = try Data(contentsOf: fileURL)
    do {
      return try JSONDecoder().decode(Workspace.self, from: data)
    } catch {
      try? FileManager.default.moveItem(at: fileURL, to: backupURL)
      throw UnreadableState(backup: backupURL, underlying: error)
    }
  }

  private var backupURL: URL {
    let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    return fileURL.deletingPathExtension().appendingPathExtension("\(stamp).broken.json")
  }

  public func save(_ workspace: Workspace) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(workspace).write(to: fileURL, options: .atomic)
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

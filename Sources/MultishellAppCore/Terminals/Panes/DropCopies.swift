import Foundation
import MultishellCore

/// The copies a pane is handed a path to: files a drag promised rather than
/// handed over, and images pasted from the clipboard; see terminals.md.
public enum DropCopies {
  /// How long a copy is kept: long enough that a prompt written today still
  /// resolves next week.
  static let retention: TimeInterval = 7 * 24 * 60 * 60

  /// A directory for one drag's or paste's files, made fresh so their names
  /// land in it unchanged.
  public static func makeDirectory(in parent: URL = Paths.dropsDirectory) throws -> URL {
    let directory = parent.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Dated now, so the sweep keeps it for `retention` from today.
  public static func keep(_ directory: URL) {
    let now: [FileAttributeKey: Any] = [.modificationDate: Date()]
    try? FileManager.default.setAttributes(now, ofItemAtPath: directory.path)
  }

  /// One drop's directory that nothing will name.
  public static func remove(_ directory: URL) {
    try? FileManager.default.removeItem(at: directory)
  }

  /// Drops older than `retention` removed, off the directory's own timestamps
  /// rather than a record this would have to keep true.
  static func sweep(
    in parent: URL = Paths.dropsDirectory,
    keeping retention: TimeInterval = retention,
    now: Date = Date(),
  ) {
    let manager = FileManager.default
    let drops =
      (try? manager.contentsOfDirectory(
        at: parent,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles],
      )) ?? []
    for drop in drops {
      guard let modified = drop.modificationDate, now.timeIntervalSince(modified) > retention else {
        continue
      }
      try? manager.removeItem(at: drop)
    }
  }
}

import Foundation
import MultishellCore

/// The copies kept for files a drag promised rather than handed over, macOS
/// materialising one the pane's shell cannot read; see terminals.md.
public enum PromisedDropCopies {
  /// How long a drag's copies are kept: long enough that a prompt written
  /// today still resolves next week.
  static let retention: TimeInterval = 7 * 24 * 60 * 60

  /// A directory for one drag's files, made fresh so the promised names land
  /// in it unchanged.
  public static func makeDirectory(in parent: URL = Paths.dropsDirectory) throws -> URL {
    let directory = parent.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Drops older than `retention` removed, off the directory's own timestamps
  /// rather than a record this would have to keep true.
  static func sweep(
    in parent: URL = Paths.dropsDirectory, keeping retention: TimeInterval = retention,
    now: Date = Date()
  ) {
    let manager = FileManager.default
    let drops =
      (try? manager.contentsOfDirectory(
        at: parent, includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles])) ?? []
    for drop in drops {
      let modified = try? drop.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate
      guard let modified, now.timeIntervalSince(modified) > retention else { continue }
      try? manager.removeItem(at: drop)
    }
  }
}

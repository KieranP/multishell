import Foundation
import MultishellCore

/// The copies kept for files a drag promised rather than handed over, macOS
/// materialising one the pane's shell cannot read; see terminals.md.
public enum DroppedFiles {
  /// How long a drag's copies are kept: long enough that a prompt written
  /// today still resolves next week.
  public static let keep: TimeInterval = 7 * 24 * 60 * 60

  /// Whether a dragged path is a copy macOS made for this drop, read off the
  /// `TemporaryItems` and `NSIRD_` marks it carries; see terminals.md.
  public static func isTemporaryCopy(_ url: URL) -> Bool {
    let components = url.standardizedFileURL.pathComponents
    if components.contains(where: { $0.hasPrefix("NSIRD_") }) { return true }
    let temporary = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .standardizedFileURL.pathComponents
    guard components.count > temporary.count, Array(components.prefix(temporary.count)) == temporary
    else { return false }
    return components.dropFirst(temporary.count).dropLast().contains("TemporaryItems")
  }

  /// Whether a drag's own paths are enough, or its promise must be asked
  /// too. Anything carrying a copy needs the promise.
  public static func needsPromise(for urls: [URL]) -> Bool {
    urls.isEmpty || urls.contains { isTemporaryCopy($0) }
  }

  /// The files in a drag that are the user's own and keep their path. The
  /// rest are copies, asked for again through the promise.
  public static func own(among urls: [URL]) -> [URL] {
    urls.filter { !isTemporaryCopy($0) }
  }

  /// A directory for one drag's files, made fresh so the promised names land
  /// in it unchanged.
  public static func makeDirectory(in parent: URL = Paths.dropsDirectory) throws -> URL {
    let directory = parent.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Drops older than `keep` removed, off the directory's own timestamps
  /// rather than a record this would have to keep true.
  public static func sweep(
    in parent: URL = Paths.dropsDirectory, keeping keep: TimeInterval = keep, now: Date = Date()
  ) {
    let manager = FileManager.default
    let drops =
      (try? manager.contentsOfDirectory(
        at: parent, includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles])) ?? []
    for drop in drops {
      let modified = try? drop.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate
      guard let modified, now.timeIntervalSince(modified) > keep else { continue }
      try? manager.removeItem(at: drop)
    }
  }
}

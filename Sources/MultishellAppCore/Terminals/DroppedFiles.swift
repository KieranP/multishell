import Foundation
import MultishellCore

/// The copies kept for files a drag promised rather than handed over.
///
/// The app is given the promised file in a directory macOS opens to it
/// alone, so a path pasted from there is one the pane's own shell cannot
/// open. The copy is taken into a directory of the app's own, one per drag
/// so two screenshots of the same name cannot collide and the name the user
/// saw is the name the agent reads.
///
/// The copies are the user's now: a drop is read at the prompt minutes
/// later, and a mention that outlives the session should still resolve. Old
/// drags are swept at launch instead, since nothing else would ever remove
/// them.
public enum DroppedFiles {
  /// How long a drag's copies are kept. Long enough that a prompt written
  /// today still resolves next week, short enough that the directory is not
  /// an album.
  public static let keep: TimeInterval = 7 * 24 * 60 * 60

  /// Whether a dragged path is a copy macOS made for this drop rather than a
  /// file the user has.
  ///
  /// Which way a drag is taken turns on this. A copy only the receiving app
  /// may read has to be asked for again through its promise; a file the user
  /// has must keep its own path, or an agent told to edit what was dropped
  /// would edit a copy that is swept in a week and never the file.
  ///
  /// Reading the file cannot tell the two apart — the app can read both, and
  /// that is the whole trap — so the marks the copy carries are read instead:
  /// it is put under the per-user temporary directory's `TemporaryItems`, in
  /// a directory named for whoever promised it (`NSIRD_screencaptureui_…`).
  /// Either mark is enough, since a copy put somewhere else still carries its
  /// name, and a directory of the user's own called `TemporaryItems` is not
  /// under the temporary directory.
  public static func isTemporaryCopy(_ url: URL) -> Bool {
    let components = url.standardizedFileURL.pathComponents
    if components.contains(where: { $0.hasPrefix("NSIRD_") }) { return true }
    let temporary = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .standardizedFileURL.pathComponents
    guard components.count > temporary.count, Array(components.prefix(temporary.count)) == temporary
    else { return false }
    return components.dropFirst(temporary.count).dropLast().contains("TemporaryItems")
  }

  /// Whether a drag's own paths are enough, or its promise has to be asked
  /// for as well.
  ///
  /// A drag offering no path at all is one whose files are not written yet,
  /// and there is nothing but the promise to ask; a drag whose paths are all
  /// the user's own needs nothing more. Anything else carries at least one
  /// copy, which only the promise can turn into a file the pane can open.
  public static func needsPromise(for urls: [URL]) -> Bool {
    urls.isEmpty || urls.contains { isTemporaryCopy($0) }
  }

  /// The files in a drag that are the user's own, which keep the path they
  /// are at. The rest are copies, and are asked for again through the drag's
  /// promise; a drag of both at once pastes these and then those, rather than
  /// letting the ones nobody promised go missing.
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

  /// Drops older than `keep` removed. Reads the directory's own timestamps
  /// rather than a record of its own, which would be one more thing to keep
  /// true; a drop whose files were read yesterday is not swept for it.
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

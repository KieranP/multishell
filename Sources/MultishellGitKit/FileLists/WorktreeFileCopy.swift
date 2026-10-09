import Foundation

enum WorktreeFileCopy {
  /// A directory entry by entry, asking `isStopRequested` before each, so a large
  /// one ends at the next file on Cancel; `copyItem` alone takes it whole.
  static func copy(_ source: URL, to destination: URL, isStopRequested: () -> Bool) throws {
    let manager = FileManager.default
    var isDirectory: ObjCBool = false
    guard manager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue,
      (try? source.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true
    else {
      try manager.copyItem(at: source, to: destination)
      return
    }
    // Modes go on last, deepest first: a 0555 folder made first takes no children.
    var made: [(directory: URL, source: URL)] = []
    defer { for (directory, source) in made.reversed() { copyMode(of: source, to: directory) } }
    try manager.createDirectory(at: destination, withIntermediateDirectories: false)
    made.append((destination, source))
    // Without this handler the enumerator skips a folder it cannot read, and
    // the copy reads as whole where `copyItem` would have thrown.
    var unread: (any Error)?
    let entries = manager.enumerator(
      at: source,
      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
      options: [.producesRelativePathURLs],
    ) { _, error in
      unread = error
      return false
    }
    do {
      while let entry = entries?.nextObject() as? URL {
        guard !isStopRequested() else { throw WorktreeFileStopped() }
        let target = destination.appendingPathComponent(entry.relativePath)
        let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        if values.isDirectory == true, values.isSymbolicLink != true {
          try manager.createDirectory(at: target, withIntermediateDirectories: false)
          made.append((target, entry))
        } else {
          try manager.copyItem(at: entry, to: target)
        }
      }
      if let unread { throw unread }
    } catch {
      // Half a directory would read as placed, and nothing places over it.
      made = []
      try? manager.removeItem(at: destination)
      throw error
    }
  }

  private static func copyMode(of source: URL, to directory: URL) {
    let manager = FileManager.default
    if let mode = try? manager.attributesOfItem(atPath: source.path)[.posixPermissions] {
      try? manager.setAttributes([.posixPermissions: mode], ofItemAtPath: directory.path)
    }
  }
}

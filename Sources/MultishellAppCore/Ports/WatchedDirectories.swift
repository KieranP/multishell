import Foundation

/// The directories one stream watches, matched by real path: FSEvents names
/// `/private/var` where a caller may have said `/var`.
struct WatchedDirectories: Sendable {
  /// Where a path falls: the deepest watched directory holding it, by index,
  /// and the path below it, empty for the directory itself.
  private struct Location {
    let entryIndex: Int
    let relative: String
  }

  private struct Directory: Sendable {
    let realPath: String
    let url: URL
  }

  /// Deepest first, so a change inside `.git` is the git directory's and not
  /// the worktree's around it.
  private let entries: [Directory]

  var realPaths: [String] { entries.map(\.realPath) }
  /// As the caller spelled them.
  var directories: [URL] { entries.map(\.url) }

  /// Stats every path, so not on the main actor. A directory not there is left out.
  init(_ directories: [URL]) {
    entries = directories.compactMap { url in
      guard let resolved = realpath(url.path, nil) else { return nil }
      defer { free(resolved) }
      return Directory(realPath: String(cString: resolved), url: url)
    }
    .sorted { $0.realPath.count > $1.realPath.count }
  }

  private func location(ofEventAt path: String) -> Location? {
    let path = path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    for (index, entry) in entries.enumerated() {
      if path == entry.realPath { return Location(entryIndex: index, relative: "") }
      let prefix = entry.realPath.hasSuffix("/") ? entry.realPath : entry.realPath + "/"
      guard path.hasPrefix(prefix) else { continue }
      return Location(entryIndex: index, relative: String(path.dropFirst(prefix.count)))
    }
    return nil
  }

  /// The directory holding the change, or the entry itself at the top of a
  /// watched directory. Names a reader must tell apart keep their whole path.
  private func reportedURL(for location: Location) -> URL {
    let root = entries[location.entryIndex].url
    let relative = location.relative
    guard !relative.isEmpty else { return root }
    let components = relative.split(separator: "/")
    let parent = components.dropLast().joined(separator: "/")
    let name = components.last ?? ""
    let keepsWholePath =
      name.hasSuffix(".lock") || name == ".gitignore" || name.hasPrefix("fsmonitor--daemon")
    let reported = keepsWholePath || parent.isEmpty ? relative : parent
    return root.appending(path: reported, directoryHint: .inferFromPath)
  }

  func reportedURL(forEventAt path: String) -> URL? {
    location(ofEventAt: path).map(reportedURL(for:))
  }
}

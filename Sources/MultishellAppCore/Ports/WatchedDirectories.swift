import Foundation
import MultishellCore

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

  private let entries: [Directory]
  /// The first entry for each real path, which `location` looks up from the
  /// event's deepest folder up, so `.git` wins over the worktree around it.
  private let entryIndexByRealPath: [String: Int]

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
    entryIndexByRealPath = Dictionary(
      keepingFirst: entries.enumerated().map { ($0.element.realPath, $0.offset) }
    )
  }

  /// A lookup per folder above the event, not a scan of every entry: an
  /// install's 80,000 events took 2.3 s against 300 watched directories.
  private func location(ofEventAt path: String) -> Location? {
    let path = path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    if let index = entryIndexByRealPath[path] { return Location(entryIndex: index, relative: "") }
    var end = path.endIndex
    while let slash = path[..<end].lastIndex(of: "/") {
      let directory = slash == path.startIndex ? "/" : String(path[..<slash])
      if let index = entryIndexByRealPath[directory] {
        return Location(entryIndex: index, relative: String(path[path.index(after: slash)...]))
      }
      end = slash
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

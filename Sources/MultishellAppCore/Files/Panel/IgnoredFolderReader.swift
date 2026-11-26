import Foundation

/// Reads an ignored folder's entries from disk. Blocking: callers run it
/// through `runOnDispatch`, a folder on a dead mount holding the read.
enum IgnoredFolderReader {
  /// A link counts as a folder only where it leads to one inside the worktree,
  /// so nothing outside is listed; see Docs/design/files/panel.md.
  static func entries(of path: String, in worktree: URL) -> [IgnoredFolderEntry] {
    guard WorktreeLinkTarget.path(of: path, in: worktree) != nil else { return [] }
    let folder = worktree.appending(path: path)
    let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    return names.map { name in
      let entry = folder.appending(path: name)
      var isDirectory: ObjCBool = false
      FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDirectory)
      let isLink = (try? entry.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink
      let staysInside =
        isLink != true || WorktreeLinkTarget.path(of: "\(path)/\(name)", in: worktree) != nil
      return IgnoredFolderEntry(name: name, isFolder: isDirectory.boolValue && staysInside)
    }
  }
}

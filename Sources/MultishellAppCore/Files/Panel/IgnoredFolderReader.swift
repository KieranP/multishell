import Foundation

/// Reads an ignored folder's entries from disk. Blocking: callers run it
/// through `runOnDispatch`, a folder on a dead mount holding the read.
enum IgnoredFolderReader {
  static func entries(of folder: URL) -> [IgnoredFolderEntry] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    return names.map { name in
      var isDirectory: ObjCBool = false
      FileManager.default.fileExists(
        atPath: folder.appending(path: name).path,
        isDirectory: &isDirectory,
      )
      return IgnoredFolderEntry(name: name, isFolder: isDirectory.boolValue)
    }
  }
}

import MultishellCore

extension AllChangesReading {
  /// The read files a watcher batch named, by path or by the folder holding them;
  /// one unread or stale is read once near, one past the cap or an image as the list moves.
  func filesTouched(by changed: [String]) -> [AllChangesFile] {
    // Substrings of each path, so a batch over thousands of files builds no strings.
    let changed = Set(changed.map { $0[...] })
    return files.filter { file in
      guard case .read = file.content, !file.isStale else { return false }
      let path = file.path
      let folder = path.unicodeScalars.lastIndex(of: "/").map { path[..<$0] } ?? ""
      return changed.contains(path[...]) || changed.contains(folder)
    }
  }

  /// The files inside repositories whose git moved, by their folders: the
  /// rest of the worktree's diffs stand.
  func paths(inRepositories folders: Set<String>) -> Set<String> {
    Set(files.map(\.path).filter { path in folders.contains(where: path.isPath(under:)) })
  }
}

import MultishellCore

extension AllChangesReading {
  /// Whether a batch named the path or the folder holding it.
  static func isTouched(by changed: [String]) -> (String) -> Bool {
    // Substrings of each path, so a batch over thousands of files builds no strings.
    let changed = Set(changed.map { $0[...] })
    return { path in
      let folder = path.unicodeScalars.lastIndex(of: "/").map { path[..<$0] } ?? ""
      return changed.contains(path[...]) || changed.contains(folder)
    }
  }

  /// The read files a watcher batch named, by path or by the folder holding them;
  /// one unread or stale is read once near, one past the cap or an image as the list moves.
  func filesTouched(by changed: [String]) -> [AllChangesFile] {
    let isTouched = Self.isTouched(by: changed)
    return files.filter { file in
      guard case .read = file.content, !file.isStale else { return false }
      return isTouched(file.path)
    }
  }

  /// The files inside repositories whose git moved, by their folders: the
  /// rest of the worktree's diffs stand.
  func paths(inRepositories folders: Set<String>) -> Set<String> {
    Set(files.map(\.path).filter { path in folders.contains(where: path.isPath(under:)) })
  }
}

import MultishellCore

extension AllChangesReading {
  /// The read files a watcher batch named, by path or by the folder holding them;
  /// one unread or stale is read once near, one past the cap or an image as the list moves.
  func filesTouched(by changed: [String]) -> [AllChangesFile] {
    let batch = WatcherBatch(changed)
    return files.filter { file in
      guard case .read = file.content, !file.isStale else { return false }
      return batch.touches(file.path)
    }
  }

  /// The files inside repositories whose git moved, by their folders: the
  /// rest of the worktree's diffs stand.
  func paths(inRepositories folders: Set<String>) -> Set<String> {
    Set(files.map(\.path).filter { path in folders.contains(where: path.isPath(under:)) })
  }
}

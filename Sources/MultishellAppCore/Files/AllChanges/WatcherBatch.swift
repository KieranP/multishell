/// The paths one watcher batch named, which touch a file by its path or its folder.
struct WatcherBatch {
  // Substrings of each path, so a batch over thousands of files builds no strings.
  private let changed: Set<Substring>

  init(_ changed: [String]) {
    self.changed = Set(changed.map { $0[...] })
  }

  func touches(_ path: String) -> Bool {
    let folder = path.unicodeScalars.lastIndex(of: "/").map { path[..<$0] } ?? ""
    return changed.contains(path[...]) || changed.contains(folder)
  }
}

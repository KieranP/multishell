/// What git said about which of one worktree's directories it ignores, by path
/// relative to the worktree, so a change under one asks git nothing again.
struct IgnoreVerdicts {
  private var isIgnoredByPath: [String: Bool] = [:]

  /// `a`, `a/b`, `a/b/c` for `a/b/c`, one at a time: a lookup mostly stops at the first,
  /// and building them all took 35 ms of a 5,000-directory batch under `node_modules`.
  private static func directories(leadingTo path: String) -> some Sequence<String> {
    sequence(state: path.startIndex) { start -> String? in
      while start < path.endIndex {
        let end = path[start...].firstIndex(of: "/") ?? path.endIndex
        defer { start = end < path.endIndex ? path.index(after: end) : end }
        if end > start { return String(path[..<end]) }
      }
      return nil
    }
  }

  /// For each path git has no answer for yet, the shallowest directory on its
  /// way still unasked; a path under a known ignored directory needs none.
  func unasked(on paths: [String]) -> [String] {
    var unasked: [String] = []
    var listed: Set<String> = []
    for path in paths {
      for prefix in Self.directories(leadingTo: path) {
        guard let ignored = isIgnoredByPath[prefix] else {
          if listed.insert(prefix).inserted { unasked.append(prefix) }
          break
        }
        if ignored { break }
      }
    }
    return unasked
  }

  /// `true` where a directory on the way to `path`, or `path` itself, is
  /// ignored; `nil` where git has not been asked far enough to say.
  func isIgnored(_ path: String) -> Bool? {
    for prefix in Self.directories(leadingTo: path) {
      guard let ignored = isIgnoredByPath[prefix] else { return nil }
      if ignored { return true }
    }
    return false
  }

  /// Drops every answer for a path under any of `paths`, keeping their own,
  /// in one pass: an unpacked archive names thousands of sibling directories.
  mutating func forget(below paths: Set<String>) {
    guard !paths.isEmpty else { return }
    isIgnoredByPath = isIgnoredByPath.filter { path, _ in
      !Self.directories(leadingTo: path).dropLast().contains(where: paths.contains)
    }
  }

  mutating func record(asked: [String], ignored: Set<String>) {
    for path in asked { isIgnoredByPath[path] = ignored.contains(path) }
  }
}

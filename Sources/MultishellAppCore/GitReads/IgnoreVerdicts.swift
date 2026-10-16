/// What git said about which of one worktree's directories it ignores, by path
/// relative to the worktree, so a change under one asks git nothing again.
struct IgnoreVerdicts {
  private var isIgnoredByPath: [String: Bool] = [:]

  /// `a`, `a/b`, `a/b/c` for `a/b/c`.
  private static func directories(leadingTo path: String) -> [String] {
    let components = path.split(separator: "/")
    return components.indices.map { components[...$0].joined(separator: "/") }
  }

  /// For each path git has no answer for yet, the shallowest directory on its
  /// way still unasked; a path under a known ignored directory needs none.
  func unasked(on paths: [String]) -> [String] {
    var unasked: [String] = []
    for path in paths {
      for prefix in Self.directories(leadingTo: path) {
        guard let ignored = isIgnoredByPath[prefix] else {
          if !unasked.contains(prefix) { unasked.append(prefix) }
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

  /// Drops every answer for a path under `path`, keeping `path`'s own.
  mutating func forget(below path: String) {
    isIgnoredByPath = isIgnoredByPath.filter { !$0.key.hasPrefix(path + "/") }
  }

  mutating func record(asked: [String], ignored: Set<String>) {
    for path in asked { isIgnoredByPath[path] = ignored.contains(path) }
  }
}

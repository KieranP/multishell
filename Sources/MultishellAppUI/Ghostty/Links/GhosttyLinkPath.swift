import Foundation

/// The file on disk a link's text names. libghostty joins a relative path to the
/// shell's directory only where the file is there; the rest is looked for here.
enum GhosttyLinkPath {
  /// A compiler's `Sources/A.swift:12:5` is tried without its line and column,
  /// libghostty's pattern taking `:` as part of the path.
  static func existingPath(of text: String, in directory: URL) -> String? {
    let paths = [text, withoutLineAndColumn(text)].compactMap(\.self)
      .map { NSString(string: withVariablesExpanded($0, in: directory)).expandingTildeInPath }
    if paths[0].hasPrefix("/") {
      return paths.first(where: FileManager.default.fileExists)
    }
    let inDirectory = paths.map { directory.appending(path: $0).path }
    if let found = inDirectory.first(where: FileManager.default.fileExists) { return found }
    // Walked once, and only on a miss: each step up is a stat a dead share can hold.
    guard let root = repositoryRoot(containing: directory) else { return nil }
    return paths.flatMap { [$0] + [withoutDiffSide($0)].compactMap(\.self) }
      .map { root.appending(path: $0).path }
      .first(where: FileManager.default.fileExists)
  }

  /// libghostty's pattern takes a `$VAR/` path; only these two have the
  /// pane's own value here, its other variables being the shell's.
  private static func withVariablesExpanded(_ path: String, in directory: URL) -> String {
    for (name, value) in [("$HOME/", NSHomeDirectory()), ("$PWD/", directory.path)]
    where path.hasPrefix(name) {
      return value + "/" + path.dropFirst(name.count)
    }
    return path
  }

  /// `rg` follows the line with the match, `src/main.rs:12:fn`.
  private static func withoutLineAndColumn(_ text: String) -> String? {
    let stripped = text.replacing(#/:\d+(:[^/]*)?$/#, with: "")
    return stripped == text ? nil : stripped
  }

  /// `git diff` names both sides from the repository root, as `a/…` and `b/…`.
  private static func withoutDiffSide(_ path: String) -> String? {
    guard path.hasPrefix("a/") || path.hasPrefix("b/") else { return nil }
    return String(path.dropFirst(2))
  }

  /// A worktree's `.git` is a file and a repository's a folder; either marks it.
  private static func repositoryRoot(containing directory: URL) -> URL? {
    var candidate = directory.standardizedFileURL
    while true {
      if FileManager.default.fileExists(atPath: candidate.appending(path: ".git").path) {
        return candidate
      }
      let parent = candidate.deletingLastPathComponent()
      if parent.path == candidate.path { return nil }
      candidate = parent
    }
  }
}

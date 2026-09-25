import Foundation

extension WorktreeGit {
  static let absolutePathFormat = "--path-format=absolute"

  /// The flag came in git 2.31. An older git echoes it back as a flag it does
  /// not know and answers relative to where it ran, so that is resolved here.
  static func absolutePaths(in output: String, from directory: URL) -> [URL] {
    var lines = output.split(whereSeparator: \.isNewline).map(String.init)
    if lines.first == absolutePathFormat { lines.removeFirst() }
    return lines.map { directoryURL($0, relativeTo: directory) }
  }

  /// A directory as git wrote it, absolute or relative to `base`.
  static func directoryURL(_ written: String, relativeTo base: URL) -> URL {
    written.hasPrefix("/")
      ? URL(fileURLWithPath: written, isDirectory: true)
      : base.appendingPathComponent(written, isDirectory: true).standardizedFileURL
  }

  /// Where a linked checkout's `.git` file says its record is, relative or absolute.
  static func recordDirectory(namedBy checkout: URL) -> URL? {
    guard
      let gitFile = try? String(
        contentsOf: checkout.appendingPathComponent(".git"), encoding: .utf8),
      let line = gitFile.split(separator: "\n").first, line.hasPrefix("gitdir: ")
    else { return nil }
    return directoryURL(String(line.dropFirst("gitdir: ".count)), relativeTo: checkout)
  }

  /// A dangling link kept by name, as git lists a worktree below one.
  static func realPath(of url: URL) -> String {
    (url.resolvedAsFarAsItExists(keepingDanglingLinks: true) ?? url.standardizedFileURL).path
  }
}

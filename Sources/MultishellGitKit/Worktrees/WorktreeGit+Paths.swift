import Foundation
import MultishellCore

extension WorktreeGit {
  static let absolutePathsFlag = "--path-format=absolute"

  /// The flag came in git 2.31. An older git echoes it back as a flag it does
  /// not know and answers relative to where it ran, so that is resolved here.
  static func absolutePaths(in output: String, from directory: URL) -> [URL] {
    var lines = output.split(whereSeparator: \.isNewline).map(String.init)
    if lines.first == absolutePathsFlag { lines.removeFirst() }
    return lines.map { directoryURL($0, relativeTo: directory) }
  }

  /// A directory as git wrote it, absolute or relative to `base`.
  private static func directoryURL(_ written: String, relativeTo base: URL) -> URL {
    written.hasPrefix("/")
      ? URL(fileURLWithPath: written, isDirectory: true)
      : base.appendingPathComponent(written, isDirectory: true).standardizedFileURL
  }

  /// Where a linked checkout's `.git` file says its record is, relative or absolute.
  static func recordDirectoryFromGitFile(in checkout: URL) -> URL? {
    directoryNamed(
      inFile: checkout.appendingPathComponent(".git"), after: "gitdir: ", relativeTo: checkout)
  }

  /// The directory a git-written file names on its first line, after `prefix`.
  static func directoryNamed(
    inFile file: URL, after prefix: String = "", relativeTo base: URL
  )
    -> URL?
  {
    guard let text = try? String(contentsOf: file, encoding: .utf8),
      let line = text.split(whereSeparator: \.isNewline).first, line.hasPrefix(prefix)
    else { return nil }
    return directoryURL(String(line.dropFirst(prefix.count)), relativeTo: base)
  }

  /// A dangling link kept by name, as git lists a worktree below one.
  static func pathAsGitLists(_ url: URL) -> String {
    (url.resolvedAsFarAsItExists(keepingDanglingLinks: true) ?? url.standardizedFileURL).path
  }

  static func sameComparablePath(_ a: URL, _ b: URL) -> Bool {
    a.comparablePath == b.comparablePath
  }
}

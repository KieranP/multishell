import Foundation
import MultishellCore

extension WorktreeGit {
  static let absolutePathsFlag = "--path-format=absolute"

  static func absolutePaths(in output: String) -> [URL] {
    output.gitLines.map { URL(fileURLWithPath: $0, isDirectory: true) }
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
      inFile: checkout.appendingPathComponent(".git"),
      relativeTo: checkout,
      after: "gitdir: ",
    )
  }

  /// The directory a git-written file names on its first line, after `prefix`.
  static func directoryNamed(
    inFile file: URL,
    relativeTo base: URL,
    after prefix: String = "",
  )
    -> URL?
  {
    guard let text = try? String(contentsOf: file, encoding: .utf8),
      let path = text.gitLines.first?.removingPrefix(prefix)
    else { return nil }
    return directoryURL(path, relativeTo: base)
  }

  /// A dangling link kept by name, as git lists a worktree below one.
  static func pathAsGitLists(_ url: URL) -> String {
    (url.resolvedAsFarAsItExists(keepingDanglingLinks: true) ?? url.standardizedFileURL).path
  }

  static func sameComparablePath(_ a: URL, _ b: URL) -> Bool {
    a.comparablePath == b.comparablePath
  }
}

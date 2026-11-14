import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension GitHarness {
  /// Shows the panel on `main` with `node_modules/` ignored and opened, its
  /// `left-pad` folder listed from the disk.
  func openIgnoredFolder(in main: Worktree) async throws -> URL {
    let row = try await ignoredFolderRow(in: main)
    model.toggleFolder(row, in: main.id)
    try await waitUntil { self.listsLeftPad(in: main) }
    #expect(listsLeftPad(in: main))
    return main.path.appending(path: "node_modules/left-pad", directoryHint: .isDirectory)
  }

  /// The panel shown on `main` with `node_modules/` ignored and still shut.
  func ignoredFolderRow(in main: Worktree) async throws -> FileTreeRow {
    try writeIgnored("node_modules/left-pad/index.js", matching: "node_modules/", in: main)
    model.select(main)
    model.setShowsFilesPanel(true)
    try await waitUntil { self.model.fileTreeRows(of: main.id).contains { $0.isIgnored } }
    return try #require(model.fileTreeRows(of: main.id).first { $0.path == "node_modules" })
  }

  func listsLeftPad(in main: Worktree) -> Bool {
    model.fileTreeRows(of: main.id).contains { $0.path == "node_modules/left-pad" }
  }

  /// `path` written in `worktree`, which git ignores by `pattern` in its exclude file.
  func writeIgnored(_ path: String, matching pattern: String, in worktree: Worktree) throws {
    let file = worktree.path.appending(path: path)
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    try "\(path)\n".write(to: file, atomically: true, encoding: .utf8)
    try "\(pattern)\n".write(
      to: worktree.path.appending(path: ".git/info/exclude"),
      atomically: true,
      encoding: .utf8,
    )
  }
}

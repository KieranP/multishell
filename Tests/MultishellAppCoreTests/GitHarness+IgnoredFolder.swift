import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension GitHarness {
  /// Shows the panel on `main` with `node_modules/` ignored and opened, its
  /// `left-pad` folder listed from the disk.
  func openIgnoredFolder(in main: Worktree) async throws -> URL {
    let leftPad = main.path.appending(path: "node_modules/left-pad", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: leftPad, withIntermediateDirectories: true)
    try "pad\n".write(to: leftPad.appending(path: "index.js"), atomically: true, encoding: .utf8)
    try "node_modules/\n".write(
      to: main.path.appending(path: ".git/info/exclude"),
      atomically: true,
      encoding: .utf8,
    )
    model.select(main)
    model.setShowsFilesPanel(true)
    try await waitUntil { self.model.fileTreeRows(of: main.id).contains { $0.isIgnored } }
    let row = try #require(model.fileTreeRows(of: main.id).first { $0.path == "node_modules" })
    model.toggleFolder(row, in: main.id)
    try await waitUntil { self.listsLeftPad(in: main) }
    #expect(listsLeftPad(in: main))
    return leftPad
  }

  func listsLeftPad(in main: Worktree) -> Bool {
    model.fileTreeRows(of: main.id).contains { $0.path == "node_modules/left-pad" }
  }
}

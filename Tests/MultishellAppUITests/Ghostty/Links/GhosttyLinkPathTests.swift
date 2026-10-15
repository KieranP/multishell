import Foundation
import TestScratch
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyLinkPathTests {
  private func existingPath(_ text: String, in directory: URL) -> String? {
    GhosttyLinkPath.existingPath(of: text, in: directory)
      .map { URL(filePath: $0).standardized.path }
  }

  @Test func aRelativePathIsLookedForInThePanesDirectory() throws {
    let directory = try Scratch.directory("link-path")
    defer { Scratch.remove(directory) }
    let sub = directory.appendingPathComponent("sub")
    try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: false)
    let document = sub.appendingPathComponent("notes.txt")
    try "notes".write(to: document, atomically: true, encoding: .utf8)

    #expect(existingPath("sub/notes.txt", in: directory) == document.path)
    #expect(existingPath("./sub/notes.txt", in: directory) == document.path)
    #expect(existingPath("../sub/notes.txt", in: sub) == document.path)
    #expect(existingPath("notes.txt", in: directory) == nil, "not in the pane's directory")
  }

  @Test func aDiffsSidePrefixOrARootRelativePathIsReadFromTheRepositoryRoot() throws {
    let worktree = try Scratch.directory("link-worktree")
    defer { Scratch.remove(worktree) }
    try "gitdir: /elsewhere".write(
      to: worktree.appendingPathComponent(".git"),
      atomically: true,
      encoding: .utf8,
    )
    let launch = worktree.appendingPathComponent("Sources/Launch")
    try FileManager.default.createDirectory(at: launch, withIntermediateDirectories: true)
    let source = launch.appendingPathComponent("EditorLaunch.swift")
    try "enum EditorLaunch {}".write(to: source, atomically: true, encoding: .utf8)

    for text in [
      "a/Sources/Launch/EditorLaunch.swift",
      "b/Sources/Launch/EditorLaunch.swift",
      "Sources/Launch/EditorLaunch.swift",
    ] {
      #expect(existingPath(text, in: launch) == source.path, "\(text)")
    }
  }

  @Test func aPathInThePanesDirectoryWinsOverTheSameOneUnderTheRoot() throws {
    let worktree = try Scratch.directory("link-worktree")
    defer { Scratch.remove(worktree) }
    try FileManager.default.createDirectory(
      at: worktree.appendingPathComponent(".git"),
      withIntermediateDirectories: false,
    )
    let folderNamedA = worktree.appendingPathComponent("a")
    try FileManager.default.createDirectory(at: folderNamedA, withIntermediateDirectories: false)
    let inFolderNamedA = folderNamedA.appendingPathComponent("notes.txt")
    try "a".write(to: inFolderNamedA, atomically: true, encoding: .utf8)
    try "root".write(
      to: worktree.appendingPathComponent("notes.txt"),
      atomically: true,
      encoding: .utf8,
    )

    #expect(existingPath("a/notes.txt", in: worktree) == inFolderNamedA.path)
  }

  @Test func aCompilersLineAndColumnAreDroppedToFindTheFile() throws {
    let directory = try Scratch.directory("link-path")
    defer { Scratch.remove(directory) }
    let sources = directory.appendingPathComponent("Sources")
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: false)
    let source = sources.appendingPathComponent("A.swift")
    try "let a = 1".write(to: source, atomically: true, encoding: .utf8)

    #expect(existingPath(source.path + ":12:5", in: directory) == source.path)
    #expect(existingPath(source.path + ":12", in: directory) == source.path)
    #expect(existingPath("Sources/A.swift:3:1", in: directory) == source.path)
    #expect(existingPath("Sources/A.swift:12:fn", in: directory) == source.path, "rg's match")
    #expect(existingPath(source.path + ":x", in: directory) == nil, "not a line number")
  }

  @Test func aPathFromHomeOrThePanesDirectoryVariableExpands() throws {
    let directory = try Scratch.directory("link-path")
    defer { Scratch.remove(directory) }
    let document = directory.appendingPathComponent("notes.txt")
    try "notes".write(to: document, atomically: true, encoding: .utf8)
    let library = URL(filePath: NSHomeDirectory()).appending(path: "Library").standardized.path

    #expect(existingPath("$PWD/notes.txt", in: directory) == document.path)
    #expect(existingPath("$HOME/Library", in: directory) == library)
    #expect(existingPath("$UNSET_IN_TEST/notes.txt", in: directory) == nil)
  }

  @Test func aMissingAbsolutePathIsNoPath() throws {
    let directory = try Scratch.directory("link-path")
    defer { Scratch.remove(directory) }

    #expect(existingPath(directory.appendingPathComponent("gone.txt").path, in: directory) == nil)
  }
}

import Foundation
import Testing

@testable import MultishellGitKit

extension WorktreeFilesTests {
  @Test func aCopiedDirectoryArrivesWholeDownToItsNestedFilesAndLinks() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    let cache = repository.appending(path: "cache/deep/er")
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    try "x".write(to: cache.appending(path: "file.txt"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      atPath: cache.appending(path: "link").path,
      withDestinationPath: "file.txt",
    )

    try WorktreeFiles.place("cache", as: .copy, from: repository, to: worktree)

    let copied = worktree.appending(path: "cache/deep/er")
    #expect(try String(contentsOf: copied.appending(path: "file.txt"), encoding: .utf8) == "x")
    #expect(
      try FileManager.default.destinationOfSymbolicLink(atPath: copied.appending(path: "link").path)
        == "file.txt"
    )
  }

  @Test func aReadOnlyDirectoryIsCopiedWholeAndKeepsItsMode() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    let inner = repository.appending(path: "modules/inner")
    try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
    try "x".write(to: inner.appending(path: "file.txt"), atomically: true, encoding: .utf8)
    let copied = worktree.appending(path: "modules")
    let readOnly = [inner, repository.appending(path: "modules")]
    for directory in readOnly {
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o555],
        ofItemAtPath: directory.path,
      )
    }
    defer {
      for directory in readOnly.reversed() + [copied, copied.appending(path: "inner")] {
        try? FileManager.default.setAttributes(
          [.posixPermissions: 0o755],
          ofItemAtPath: directory.path,
        )
      }
    }

    try WorktreeFiles.place("modules", as: .copy, from: repository, to: worktree)

    #expect(
      try String(contentsOf: copied.appending(path: "inner/file.txt"), encoding: .utf8) == "x"
    )
    for directory in [copied, copied.appending(path: "inner")] {
      let mode = try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions]
      #expect(mode as? Int == 0o555)
    }
  }

  @Test func aFolderInsideACopiedDirectoryThatCannotBeReadFailsTheEntry() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    let hidden = repository.appending(path: "cache/hidden")
    try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
    try "x".write(to: hidden.appending(path: "file.txt"), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: hidden.path)
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hidden.path)
    }

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("cache", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["cache"])
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(path: "cache").path))
  }

  @Test func aFileInsideACopiedDirectoryThatCannotBeReadLeavesNoHalfCopy() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    let config = repository.appending(path: "config")
    try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
    for name in ["a.yml", "b.yml", "c.yml"] {
      try "x".write(to: config.appending(path: name), atomically: true, encoding: .utf8)
    }
    let locked = config.appending(path: "b.yml")
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path)
    }

    #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("config", as: .copy, from: repository, to: worktree)
    }
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(path: "config").path))
  }
}

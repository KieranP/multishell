import Foundation
import Testing

@testable import MultishellGitKit

extension WorktreeFilesTests {
  /// A glob may not reach out either: it expands under the repository, and
  /// each name it finds is judged against the disk like any other.
  @Test func aGlobCannotExpandOntoSomethingOutsideTheRepository() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    let outside = repository.deletingLastPathComponent().appending(path: "outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "TOP SECRET".write(to: outside.appending(path: "key"), atomically: true, encoding: .utf8)
    try "SECRET=1".write(
      to: repository.appending(path: "a.env"),
      atomically: true,
      encoding: .utf8,
    )
    try FileManager.default.createSymbolicLink(
      at: repository.appending(path: "b.env"),
      withDestinationURL: outside.appending(path: "key"),
    )

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("*.env", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["b.env"])
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: worktree.path) == ["a.env"],
      "the one that stayed inside is still placed",
    )
  }

  @Test func aPatternInAFolderNamePlacesFromEachFolderThatMatches() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    for pack in ["pack-a", "pack-b"] {
      try FileManager.default.createDirectory(
        at: repository.appending(path: pack),
        withIntermediateDirectories: true,
      )
      try "x".write(
        to: repository.appending(path: "\(pack)/.env"),
        atomically: true,
        encoding: .utf8,
      )
    }
    try WorktreeFiles.place("pack-*/.env", as: .copy, from: repository, to: worktree)
    for pack in ["pack-a", "pack-b"] {
      #expect(
        FileManager.default.fileExists(atPath: worktree.appending(path: "\(pack)/.env").path),
        "\(pack)",
      )
    }
  }

  @Test func copyingBringsEveryFileAPatternMatches() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try "one".write(
      to: repository.appending(path: ".env.local"),
      atomically: true,
      encoding: .utf8,
    )
    try "two".write(to: repository.appending(path: ".env.test"), atomically: true, encoding: .utf8)
    try WorktreeFiles.place(".env.*", as: .copy, from: repository, to: worktree)
    #expect(
      try String(contentsOf: worktree.appending(path: ".env.local"), encoding: .utf8) == "one"
    )
    #expect(
      try String(contentsOf: worktree.appending(path: ".env.test"), encoding: .utf8) == "two"
    )
  }
}

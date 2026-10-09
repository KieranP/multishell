import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
final class WorktreeFilesTests {
  let root = Scratch.path("files")

  @Test func theListIsOnePathPerLineWithoutBlanksCommentsOrRepeats() {
    let list = """
      .env

        .env.local
      # a note
      .env
      """
    #expect(WorktreeFiles.paths(in: list) == [".env", ".env.local"])
    #expect(WorktreeFiles.paths(in: "   \n\n").isEmpty)
  }

  /// The link is absolute and points at the repository's own file, so what is written through it
  /// is written there.
  @Test func linkingPointsTheWorktreeAtTheRepositorysFileRatherThanDuplicatingIt() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try FileManager.default.createDirectory(
      at: repository.appending(path: "node_modules/left-pad"),
      withIntermediateDirectories: true,
    )
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    try WorktreeFiles.place(".env\nnode_modules", as: .link, from: repository, to: worktree)

    let manager = FileManager.default
    for name in [".env", "node_modules"] {
      let attributes = try manager.attributesOfItem(atPath: worktree.appending(path: name).path)
      #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
      #expect(
        try manager.destinationOfSymbolicLink(atPath: worktree.appending(path: name).path)
          == repository.appending(path: name).path,
        "at the repository's own, by absolute path",
      )
    }
    #expect(manager.fileExists(atPath: worktree.appending(path: "node_modules/left-pad").path))
    // In place, not atomically: an atomic write renames a new file over
    // the link and would say nothing about what the link points at.
    try "SECRET=2".write(to: worktree.appending(path: ".env"), atomically: false, encoding: .utf8)
    #expect(
      try String(contentsOf: repository.appending(path: ".env"), encoding: .utf8) == "SECRET=2",
      "and a write through the link is a write to the repository's file",
    )
  }

  /// The lists run in this order and neither places anything over what is already there, which
  /// alone settles a path spelled in both.
  @Test func aPathInBothListsEndsUpTheLinkTheCopyRunsAfter() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    for placement in WorktreeFilePlacement.allCases {
      try WorktreeFiles.place(".env", as: placement, from: repository, to: worktree)
    }
    let attributes = try FileManager.default.attributesOfItem(
      atPath: worktree.appending(path: ".env").path
    )
    #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
  }

  /// git checks out a tracked symlink whether or not this branch carries its target, and placing
  /// over it would fail on it.
  @Test(arguments: WorktreeFilePlacement.allCases)
  func aDanglingSymlinkGitCheckedOutIsLeftAloneLikeAnyOtherFile(
    _ placement: WorktreeFilePlacement
  ) throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: worktree.appending(path: ".env"),
      withDestinationURL: worktree.appending(path: "not-on-this-branch"),
    )

    try WorktreeFiles.place(".env", as: placement, from: repository, to: worktree)

    #expect(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: worktree.appending(path: ".env").path
      )
        == worktree.appending(path: "not-on-this-branch").path,
      "the worktree's own is untouched",
    )
  }

  @Test func copyingBringsFilesAndFoldersAcrossAndMakesTheDirectoriesTheyNeed() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(
      at: repository.appending(path: "config/local"),
      withIntermediateDirectories: true,
    )
    try "port: 1".write(
      to: repository.appending(path: "config/local/dev.yml"),
      atomically: true,
      encoding: .utf8,
    )

    try WorktreeFiles.place(".env\nconfig/local", as: .copy, from: repository, to: worktree)
    #expect(
      try String(contentsOf: worktree.appending(path: ".env"), encoding: .utf8) == "SECRET=1"
    )
    #expect(
      try String(contentsOf: worktree.appending(path: "config/local/dev.yml"), encoding: .utf8)
        == "port: 1"
    )
  }

  @Test func aPathTheRepositoryDoesNotHaveIsSkippedRatherThanFailing() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)
    try WorktreeFiles.place(".env\n.env.local", as: .copy, from: repository, to: worktree)
    #expect(FileManager.default.fileExists(atPath: worktree.appending(path: ".env").path))
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(path: ".env.local").path))
  }

  /// git checked the tracked file out; a copy over it would be the wrong
  /// branch's.
  @Test func aFileGitAlreadyPutInTheWorktreeIsLeftAlone() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try "trunk".write(
      to: repository.appending(path: "config.yml"),
      atomically: true,
      encoding: .utf8,
    )
    try "branch".write(
      to: worktree.appending(path: "config.yml"),
      atomically: true,
      encoding: .utf8,
    )
    try WorktreeFiles.place("config.yml", as: .copy, from: repository, to: worktree)
    #expect(
      try String(contentsOf: worktree.appending(path: "config.yml"), encoding: .utf8) == "branch"
    )
  }

  @Test func aUsersOwnSkippedEntryStaysApartFromTheFailuresBesideIt() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try FileManager.default.createDirectory(
      at: repository.appending(path: "blocked"),
      withIntermediateDirectories: true,
    )
    try "x".write(
      to: repository.appending(path: "blocked/inner"),
      atomically: true,
      encoding: .utf8,
    )
    try "wall".write(to: worktree.appending(path: "blocked"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place(
        "blocked/inner\n~/.aws.json",
        as: .copy,
        from: repository,
        to: worktree,
        isRepositoryList: false,
      )
    }
    #expect(failure?.failures.map(\.path) == ["blocked/inner"])
    #expect(failure?.skipped == ["~/.aws.json"])
  }

  @Test func everythingCopiableIsCopiedAndTheFailuresAreNamedTogether() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(
      at: repository.appending(path: "blocked"),
      withIntermediateDirectories: true,
    )
    try "x".write(
      to: repository.appending(path: "blocked/inner"),
      atomically: true,
      encoding: .utf8,
    )
    // A file where the copy needs a directory, so making `blocked/` fails.
    try "wall".write(to: worktree.appending(path: "blocked"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("blocked/inner\n.env", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["blocked/inner"])
    #expect(FileManager.default.fileExists(atPath: worktree.appending(path: ".env").path))
  }

  func repositoryAndWorktree() throws -> (repository: URL, worktree: URL) {
    let repository = root.appending(path: "repo")
    let worktree = root.appending(path: "tree")
    for url in [repository, worktree] {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return (repository, worktree)
  }

  deinit { Scratch.remove(root) }
}

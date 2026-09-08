import Foundation
import Testing

@testable import MultishellGitKit

/// The copy list a project gives each new worktree.
@Suite
struct WorktreeCopierTests {
  @Test func theListIsOnePathPerLineWithoutBlanksCommentsOrRepeats() {
    let list = """
      .env

        .env.local
      # a note
      .env
      """
    #expect(WorktreeCopier.paths(in: list) == [".env", ".env.local"])
    #expect(WorktreeCopier.paths(in: "   \n\n").isEmpty)
  }

  /// Containment is decided against the disk, not against the spelling, so
  /// a `..` is refused by name rather than quietly dropped from the list.
  @Test func aPathThatReachesOutsideTheRepositoryIsRefused() throws {
    let (repository, worktree) = try directories()
    let outside = repository.deletingLastPathComponent().appending("outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "TOP SECRET".write(to: outside.appending("key"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeCopyFailure.self) {
      try WorktreeCopier().copy("../outside/key", from: repository, to: worktree)
    }
    #expect(failure?.items.map(\.path) == ["../outside/key"])
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty,
      "and nothing was copied in")
  }

  /// A leading `/` or `~` is not a way out: it lands under the repository,
  /// where there is nothing to copy, so it needs no rule of its own.
  @Test func anAbsolutePathOrATildeLandsInsideAndFindsNothing() throws {
    let (repository, worktree) = try directories()
    try WorktreeCopier().copy("/etc/passwd\n~/.ssh/id_rsa", from: repository, to: worktree)
    #expect(try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty)
  }

  @Test func copyingBringsFilesAndFoldersAcrossAndMakesTheDirectoriesTheyNeed() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(
      at: repository.appending("config/local"), withIntermediateDirectories: true)
    try "port: 1".write(
      to: repository.appending("config/local/dev.yml"), atomically: true, encoding: .utf8)

    try WorktreeCopier().copy(".env\nconfig/local", from: repository, to: worktree)
    #expect(try String(contentsOf: worktree.appending(".env"), encoding: .utf8) == "SECRET=1")
    #expect(
      try String(contentsOf: worktree.appending("config/local/dev.yml"), encoding: .utf8)
        == "port: 1")
  }

  @Test func aPathTheRepositoryDoesNotHaveIsSkippedRatherThanFailing() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(".env"), atomically: true, encoding: .utf8)
    try WorktreeCopier().copy(".env\n.env.local", from: repository, to: worktree)
    #expect(FileManager.default.fileExists(atPath: worktree.appending(".env").path))
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(".env.local").path))
  }

  /// git checked the tracked file out; a copy over it would be the wrong
  /// branch's.
  @Test func aFileGitAlreadyPutInTheWorktreeIsLeftAlone() throws {
    let (repository, worktree) = try directories()
    try "trunk".write(to: repository.appending("config.yml"), atomically: true, encoding: .utf8)
    try "branch".write(to: worktree.appending("config.yml"), atomically: true, encoding: .utf8)
    try WorktreeCopier().copy("config.yml", from: repository, to: worktree)
    #expect(try String(contentsOf: worktree.appending("config.yml"), encoding: .utf8) == "branch")
  }

  /// One path that cannot be copied should not cost the rest of the list.
  @Test func everythingCopiableIsCopiedAndTheFailuresAreNamedTogether() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(
      at: repository.appending("blocked"), withIntermediateDirectories: true)
    try "x".write(to: repository.appending("blocked/inner"), atomically: true, encoding: .utf8)
    // A file where the copy needs a directory, so making `blocked/` fails.
    try "wall".write(to: worktree.appending("blocked"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeCopyFailure.self) {
      try WorktreeCopier().copy("blocked/inner\n.env", from: repository, to: worktree)
    }
    #expect(failure?.items.map(\.path) == ["blocked/inner"])
    #expect(FileManager.default.fileExists(atPath: worktree.appending(".env").path))
  }

  /// `..` is not the only way out: a folder that is a symlink diverts the
  /// copy, and a list a repository ships is not asked about first. The two
  /// links point apart, so the destination is genuinely somewhere new
  /// rather than a file that happens to be there already.
  @Test func aSymlinkedFolderCannotDivertTheReadOrTheWrite() throws {
    let (repository, worktree) = try directories()
    let root = repository.deletingLastPathComponent()
    let read = root.appending("elsewhere-read")
    let write = root.appending("elsewhere-write")
    for url in [read, write] {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    try "TOP SECRET".write(to: read.appending("key"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: repository.appending("link"), withDestinationURL: read)
    try FileManager.default.createSymbolicLink(
      at: worktree.appending("link"), withDestinationURL: write)

    let failure = #expect(throws: WorktreeCopyFailure.self) {
      try WorktreeCopier().copy("link/key", from: repository, to: worktree)
    }
    #expect(failure?.items.map(\.path) == ["link/key"])
    #expect(
      !FileManager.default.fileExists(atPath: write.appending("key").path),
      "nothing was written outside the worktree")
  }

  /// A checkout whose `.env` is a symlink to somewhere else is a real
  /// setup, and copying the link copies no secret: the worktree ends up
  /// pointing where the repository already pointed.
  @Test func aSymlinkAtTheEndOfThePathIsCopiedAsALinkAndIsNotFollowed() throws {
    let (repository, worktree) = try directories()
    let outside = repository.deletingLastPathComponent().appending("outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "SECRET=1".write(to: outside.appending("real"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: repository.appending(".env"), withDestinationURL: outside.appending("real"))

    try WorktreeCopier().copy(".env", from: repository, to: worktree)
    let copied = try FileManager.default.attributesOfItem(atPath: worktree.appending(".env").path)
    #expect(copied[.type] as? FileAttributeType == .typeSymbolicLink)
  }

  @Test func patternsMatchWithinOneNameOnly() {
    #expect(WorktreeCopier.matches(".env.local", pattern: ".env.*"))
    #expect(WorktreeCopier.matches(".env.", pattern: ".env.*"), "`*` may take nothing")
    #expect(!WorktreeCopier.matches(".env", pattern: ".env.*"))
    #expect(WorktreeCopier.matches("a.json", pattern: "*.json"))
    #expect(!WorktreeCopier.matches("a.json.bak", pattern: "*.json"))
    #expect(WorktreeCopier.matches("config.yml", pattern: "config.???"))
    #expect(!WorktreeCopier.matches("config.yaml", pattern: "config.???"))
    #expect(WorktreeCopier.matches("aXbXc", pattern: "a*b*c"), "backtracks over both stars")
    #expect(!WorktreeCopier.matches("aXbXd", pattern: "a*b*c"))
    #expect(WorktreeCopier.matches("anything", pattern: "*"))
    #expect(WorktreeCopier.matches("", pattern: "*"))
  }

  /// `*` taking `.git` with it would copy a repository into a worktree.
  @Test func aPatternTakesAHiddenNameOnlyWhenItSpellsTheDot() {
    #expect(!WorktreeCopier.matches(".git", pattern: "*"))
    #expect(!WorktreeCopier.matches(".env", pattern: "*env"))
    #expect(WorktreeCopier.matches(".env", pattern: ".*"))
    #expect(WorktreeCopier.matches(".env.local", pattern: ".env.*"))
  }

  @Test func aPatternStandsForTheNamesItMatchesAndAPlainPathForItself() throws {
    let (repository, _) = try directories()
    for name in [".env.local", ".env.test", ".env", "notes.md", ".git"] {
      try "x".write(to: repository.appending(name), atomically: true, encoding: .utf8)
    }
    #expect(WorktreeCopier.expand(".env.*", in: repository) == [".env.local", ".env.test"])
    #expect(WorktreeCopier.expand("*", in: repository) == ["notes.md"], "no hidden names")
    #expect(WorktreeCopier.expand("nothing.*", in: repository).isEmpty)
    #expect(
      WorktreeCopier.expand("missing/file", in: repository) == ["missing/file"],
      "a plain path is itself, whether it is there or not")
  }

  @Test func aPatternInAFolderNameExpandsToEachFolderThatMatches() throws {
    let (repository, worktree) = try directories()
    for pack in ["pack-a", "pack-b"] {
      try FileManager.default.createDirectory(
        at: repository.appending(pack), withIntermediateDirectories: true)
      try "x".write(to: repository.appending("\(pack)/.env"), atomically: true, encoding: .utf8)
    }
    #expect(
      WorktreeCopier.expand("pack-?/.env", in: repository) == ["pack-a/.env", "pack-b/.env"])

    try WorktreeCopier().copy("pack-*/.env", from: repository, to: worktree)
    #expect(FileManager.default.fileExists(atPath: worktree.appending("pack-b/.env").path))
  }

  @Test func copyingBringsEveryFileAPatternMatches() throws {
    let (repository, worktree) = try directories()
    try "one".write(to: repository.appending(".env.local"), atomically: true, encoding: .utf8)
    try "two".write(to: repository.appending(".env.test"), atomically: true, encoding: .utf8)
    try WorktreeCopier().copy(".env.*", from: repository, to: worktree)
    #expect(try String(contentsOf: worktree.appending(".env.local"), encoding: .utf8) == "one")
    #expect(try String(contentsOf: worktree.appending(".env.test"), encoding: .utf8) == "two")
  }

  private func directories() throws -> (repository: URL, worktree: URL) {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appending("copier-\(UUID().uuidString)")
    let repository = root.appending("repo")
    let worktree = root.appending("tree")
    for url in [repository, worktree] {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return (repository, worktree)
  }
}

extension URL {
  fileprivate func appending(_ path: String) -> URL {
    appendingPathComponent(path)
  }
}

import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

/// The two file lists a project gives each new worktree.
@Suite
struct WorktreeFilesTests {
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

  /// Containment is decided against the disk, not against the spelling, so
  /// a `..` is refused by name rather than quietly dropped from the list.
  /// A link is no way around it: it would point at the file just as well.
  @Test(arguments: WorktreePlacement.allCases)
  func aPathThatReachesOutsideTheRepositoryIsRefused(_ placement: WorktreePlacement) throws {
    let (repository, worktree) = try directories()
    let outside = repository.deletingLastPathComponent().appending("outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "TOP SECRET".write(to: outside.appending("key"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles().place("../outside/key", as: placement, from: repository, to: worktree)
    }
    #expect(failure?.placement == placement)
    #expect(failure?.items.map(\.path) == ["../outside/key"])
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty,
      "and nothing was placed in the worktree")
  }

  /// The point of the link list: one `node_modules`, not one per worktree.
  /// The link is absolute and points at the repository's own file, so what
  /// is written through it is written there.
  @Test func linkingPointsTheWorktreeAtTheRepositorysFileRatherThanDuplicatingIt() throws {
    let (repository, worktree) = try directories()
    try FileManager.default.createDirectory(
      at: repository.appending("node_modules/left-pad"), withIntermediateDirectories: true)
    try "SECRET=1".write(to: repository.appending(".env"), atomically: true, encoding: .utf8)

    try WorktreeFiles().place(".env\nnode_modules", as: .link, from: repository, to: worktree)

    let manager = FileManager.default
    for name in [".env", "node_modules"] {
      let attributes = try manager.attributesOfItem(atPath: worktree.appending(name).path)
      #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
      #expect(
        try manager.destinationOfSymbolicLink(atPath: worktree.appending(name).path)
          == repository.appending(name).path,
        "at the repository's own, by absolute path")
    }
    #expect(manager.fileExists(atPath: worktree.appending("node_modules/left-pad").path))
    // In place, not atomically: an atomic write renames a new file over
    // the link and would say nothing about what the link points at.
    try "SECRET=2".write(to: worktree.appending(".env"), atomically: false, encoding: .utf8)
    #expect(
      try String(contentsOf: repository.appending(".env"), encoding: .utf8) == "SECRET=2",
      "and a write through the link is a write to the repository's file")
  }

  /// The two lists run in this order, and neither places anything over
  /// what is already there, which is the whole of what settles a path
  /// spelled in both.
  @Test func aPathInBothListsEndsUpTheLinkTheCopyRunsAfter() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(".env"), atomically: true, encoding: .utf8)

    let files = WorktreeFiles()
    for placement in WorktreePlacement.allCases {
      try files.place(".env", as: placement, from: repository, to: worktree)
    }
    let attributes = try FileManager.default.attributesOfItem(
      atPath: worktree.appending(".env").path)
    #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
  }

  /// git checks out a tracked symlink whether or not this branch carries
  /// its target, and what is in the way is in the way: placing over it
  /// would fail on it, which is not what "git put it there" should mean.
  @Test(arguments: WorktreePlacement.allCases)
  func aDanglingSymlinkGitCheckedOutIsLeftAloneLikeAnyOtherFile(
    _ placement: WorktreePlacement
  ) throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: worktree.appending(".env"), withDestinationURL: worktree.appending("not-on-this-branch"))

    try WorktreeFiles().place(".env", as: placement, from: repository, to: worktree)

    #expect(
      try FileManager.default.destinationOfSymbolicLink(atPath: worktree.appending(".env").path)
        == worktree.appending("not-on-this-branch").path,
      "the worktree's own is untouched")
  }

  /// A copy under a folder the link list has already linked would land in
  /// the repository, through the link, rather than in the worktree. The
  /// containment check is against the disk, so it catches that and says
  /// so instead of writing there.
  @Test func aCopyUnderALinkedFolderIsRefusedRatherThanWrittenThroughTheLink() throws {
    let (repository, worktree) = try directories()
    try FileManager.default.createDirectory(
      at: repository.appending("vendor"), withIntermediateDirectories: true)
    try "dep".write(to: repository.appending("vendor/dep"), atomically: true, encoding: .utf8)

    let files = WorktreeFiles()
    try files.place("vendor", as: .link, from: repository, to: worktree)
    let failure = #expect(throws: WorktreeFileFailure.self) {
      try files.place("vendor/dep", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.items.map(\.path) == ["vendor/dep"])
  }

  /// The pane's Cancel, which has no process to signal: it lands between
  /// paths, and what is in the worktree by then stays there.
  @Test func aStopEndsTheListAtTheNextPathAndKeepsWhatIsPlaced() throws {
    let (repository, worktree) = try directories()
    try "one".write(to: repository.appending(".env.local"), atomically: true, encoding: .utf8)
    try "two".write(to: repository.appending(".env.test"), atomically: true, encoding: .utf8)
    // Sorted, so `.env.local` is placed first and its arrival is the stop.
    let placed = worktree.appending(".env.local")

    #expect(throws: WorktreeFilesStopped.self) {
      try WorktreeFiles().place(
        ".env.*", as: .copy, from: repository, to: worktree,
        isStopped: { FileManager.default.fileExists(atPath: placed.path) })
    }
    #expect(try String(contentsOf: placed, encoding: .utf8) == "one")
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(".env.test").path))
  }

  /// Cancel excuses what it stopped, not what had already gone wrong: the
  /// stage used to be reported finished with the failures thrown away.
  @Test func aStopCarriesTheFailuresItAlreadyHad() throws {
    let (repository, worktree) = try directories()
    try FileManager.default.createDirectory(
      at: repository.appending("vendor"), withIntermediateDirectories: true)
    try "dep".write(to: repository.appending("vendor/dep"), atomically: true, encoding: .utf8)
    try "two".write(to: repository.appending("after.txt"), atomically: true, encoding: .utf8)
    let files = WorktreeFiles()
    // A folder linked into the worktree, so writing through it is refused.
    try files.place("vendor", as: .link, from: repository, to: worktree)

    // The stop lands after the first path, which is the one that failed.
    let seen = Counter()
    let stopped = #expect(throws: WorktreeFilesStopped.self) {
      try files.place(
        "vendor/dep\nafter.txt", as: .copy, from: repository, to: worktree,
        isStopped: { seen.next() > 0 })
    }

    #expect(stopped?.failures.map(\.path) == ["vendor/dep"])
    #expect(!FileManager.default.fileExists(atPath: worktree.appending("after.txt").path))
  }

  /// A leading `/` or `~` is not a way out: it lands under the repository,
  /// where there is nothing to copy, so it needs no rule of its own.
  @Test func anAbsolutePathOrATildeLandsInsideAndFindsNothing() throws {
    let (repository, worktree) = try directories()
    try WorktreeFiles().place(
      "/etc/passwd\n~/.ssh/id_rsa", as: .copy, from: repository, to: worktree)
    #expect(try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty)
  }

  @Test func copyingBringsFilesAndFoldersAcrossAndMakesTheDirectoriesTheyNeed() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(
      at: repository.appending("config/local"), withIntermediateDirectories: true)
    try "port: 1".write(
      to: repository.appending("config/local/dev.yml"), atomically: true, encoding: .utf8)

    try WorktreeFiles().place(".env\nconfig/local", as: .copy, from: repository, to: worktree)
    #expect(try String(contentsOf: worktree.appending(".env"), encoding: .utf8) == "SECRET=1")
    #expect(
      try String(contentsOf: worktree.appending("config/local/dev.yml"), encoding: .utf8)
        == "port: 1")
  }

  @Test func aPathTheRepositoryDoesNotHaveIsSkippedRatherThanFailing() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(".env"), atomically: true, encoding: .utf8)
    try WorktreeFiles().place(".env\n.env.local", as: .copy, from: repository, to: worktree)
    #expect(FileManager.default.fileExists(atPath: worktree.appending(".env").path))
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(".env.local").path))
  }

  /// git checked the tracked file out; a copy over it would be the wrong
  /// branch's.
  @Test func aFileGitAlreadyPutInTheWorktreeIsLeftAlone() throws {
    let (repository, worktree) = try directories()
    try "trunk".write(to: repository.appending("config.yml"), atomically: true, encoding: .utf8)
    try "branch".write(to: worktree.appending("config.yml"), atomically: true, encoding: .utf8)
    try WorktreeFiles().place("config.yml", as: .copy, from: repository, to: worktree)
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

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles().place("blocked/inner\n.env", as: .copy, from: repository, to: worktree)
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

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles().place("link/key", as: .copy, from: repository, to: worktree)
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

    try WorktreeFiles().place(".env", as: .copy, from: repository, to: worktree)
    let copied = try FileManager.default.attributesOfItem(atPath: worktree.appending(".env").path)
    #expect(copied[.type] as? FileAttributeType == .typeSymbolicLink)
  }

  @Test func patternsMatchWithinOneNameOnly() {
    #expect(WorktreeFiles.matches(".env.local", pattern: ".env.*"))
    #expect(WorktreeFiles.matches(".env.", pattern: ".env.*"), "`*` may take nothing")
    #expect(!WorktreeFiles.matches(".env", pattern: ".env.*"))
    #expect(WorktreeFiles.matches("a.json", pattern: "*.json"))
    #expect(!WorktreeFiles.matches("a.json.bak", pattern: "*.json"))
    #expect(WorktreeFiles.matches("config.yml", pattern: "config.???"))
    #expect(!WorktreeFiles.matches("config.yaml", pattern: "config.???"))
    #expect(WorktreeFiles.matches("aXbXc", pattern: "a*b*c"), "backtracks over both stars")
    #expect(!WorktreeFiles.matches("aXbXd", pattern: "a*b*c"))
    #expect(WorktreeFiles.matches("anything", pattern: "*"))
    #expect(WorktreeFiles.matches("", pattern: "*"))
  }

  /// `*` taking `.git` with it would copy a repository into a worktree.
  @Test func aPatternTakesAHiddenNameOnlyWhenItSpellsTheDot() {
    #expect(!WorktreeFiles.matches(".git", pattern: "*"))
    #expect(!WorktreeFiles.matches(".env", pattern: "*env"))
    #expect(WorktreeFiles.matches(".env", pattern: ".*"))
    #expect(WorktreeFiles.matches(".env.local", pattern: ".env.*"))
  }

  @Test func aPatternStandsForTheNamesItMatchesAndAPlainPathForItself() throws {
    let (repository, _) = try directories()
    for name in [".env.local", ".env.test", ".env", "notes.md", ".git"] {
      try "x".write(to: repository.appending(name), atomically: true, encoding: .utf8)
    }
    #expect(WorktreeFiles.expand(".env.*", in: repository) == [".env.local", ".env.test"])
    #expect(WorktreeFiles.expand("*", in: repository) == ["notes.md"], "no hidden names")
    #expect(WorktreeFiles.expand("nothing.*", in: repository).isEmpty)
    #expect(
      WorktreeFiles.expand("missing/file", in: repository) == ["missing/file"],
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
      WorktreeFiles.expand("pack-?/.env", in: repository) == ["pack-a/.env", "pack-b/.env"])

    try WorktreeFiles().place("pack-*/.env", as: .copy, from: repository, to: worktree)
    #expect(FileManager.default.fileExists(atPath: worktree.appending("pack-b/.env").path))
  }

  @Test func copyingBringsEveryFileAPatternMatches() throws {
    let (repository, worktree) = try directories()
    try "one".write(to: repository.appending(".env.local"), atomically: true, encoding: .utf8)
    try "two".write(to: repository.appending(".env.test"), atomically: true, encoding: .utf8)
    try WorktreeFiles().place(".env.*", as: .copy, from: repository, to: worktree)
    #expect(try String(contentsOf: worktree.appending(".env.local"), encoding: .utf8) == "one")
    #expect(try String(contentsOf: worktree.appending(".env.test"), encoding: .utf8) == "two")
  }

  private func directories() throws -> (repository: URL, worktree: URL) {
    let root = Scratch.path("files")
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

/// A `@Sendable` counter, `isStopped` being called from a closure that
/// cannot capture a mutable local.
private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0

  func next() -> Int {
    lock.withLock {
      defer { value += 1 }
      return value
    }
  }
}

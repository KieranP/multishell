import Foundation
import Synchronization
import TestScratch
import Testing

@testable import MultishellGitKit

/// The two file lists a project gives each new worktree.
@Suite
final class WorktreeFilesTests {
  private let root = Scratch.path("files")

  deinit { Scratch.remove(root) }

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

  /// Containment is decided against the disk, not the spelling, so a `..` is refused by name
  /// rather than dropped, and a link is no way around it.
  @Test(arguments: WorktreeFilePlacement.allCases)
  func aPathThatReachesOutsideTheRepositoryIsRefused(_ placement: WorktreeFilePlacement) throws {
    let (repository, worktree) = try directories()
    let outside = repository.deletingLastPathComponent().appending(path: "outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "TOP SECRET".write(to: outside.appending(path: "key"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("../outside/key", as: placement, from: repository, to: worktree)
    }
    #expect(failure?.placement == placement)
    #expect(failure?.failures.map(\.path) == ["../outside/key"])
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty,
      "and nothing was placed in the worktree")
  }

  /// The rule holds a repository to the checkout, not the user: a path they
  /// typed into project settings is used as written. See settings.md.
  @Test(arguments: [WorktreeFilePlacement.copy, .link])
  func aPathTheUserListedThemselvesIsNotHeldToTheCheckout(_ placement: WorktreeFilePlacement) throws
  {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    let skipped = try WorktreeFiles.place(
      "~/.aws.json\n$HOME/.zshrc\n/etc/passwd\n.env", as: placement, from: repository,
      to: worktree, heldToRepository: false)

    #expect(try FileManager.default.contentsOfDirectory(atPath: worktree.path) == [".env"])
    #expect(skipped == ["~/.aws.json", "$HOME/.zshrc", "/etc/passwd"])
  }

  /// The destination is mirrored from the entry rather than asked for, so
  /// even a list of the user's own places nothing outside the worktree.
  @Test func aUsersOwnEntryIsNeverPlacedOutsideTheWorktree() throws {
    let (repository, _) = try directories()
    let manager = FileManager.default
    let worktree = root.appending(path: "trees/w")
    let outside = root.appending(path: "outside")
    for url in [worktree, outside] {
      try manager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    try "TOP SECRET".write(to: outside.appending(path: "key"), atomically: true, encoding: .utf8)

    let skipped = try WorktreeFiles.place(
      "../outside/key", as: .copy, from: repository, to: worktree, heldToRepository: false)

    #expect(skipped == ["../outside/key"])
    #expect(try manager.contentsOfDirectory(atPath: worktree.path).isEmpty)
    #expect(
      !manager.fileExists(atPath: root.appending(path: "trees/outside/key").path),
      "and nothing was written beside it either")
  }

  /// Refused, not silently skipped: these used to fail only because
  /// `repo/~/.aws.json` does not exist, which is luck.
  @Test(arguments: [WorktreeFilePlacement.copy, .link])
  func noSpellingOfAPathOutsideTheRepositoryIsPlaced(_ placement: WorktreeFilePlacement) throws {
    let (repository, worktree) = try directories()
    let outside = [
      "~/.aws.json", "~", "$HOME/.aws.json", "/etc/passwd", "/", "../../../.aws.json", "..",
      "a/../../.aws.json", ".", "./",
    ]

    for path in outside {
      let failure = #expect(throws: WorktreeFileFailure.self) {
        try WorktreeFiles.place(path, as: placement, from: repository, to: worktree)
      }
      #expect(failure?.failures.map(\.path) == [path], "\(path.debugDescription)")
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty)
  }

  /// One bad entry does not cost the good ones, which is what `place` does
  /// with every other kind of failure.
  @Test func theEntriesThatStayInsideArePlacedBesideOneThatIsRefused() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place(
        ".env\n~/.aws.json", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["~/.aws.json"])
    #expect(try String(contentsOf: worktree.appending(path: ".env"), encoding: .utf8) == "SECRET=1")
  }

  /// The link is absolute and points at the repository's own file, so what is written through it
  /// is written there.
  @Test func linkingPointsTheWorktreeAtTheRepositorysFileRatherThanDuplicatingIt() throws {
    let (repository, worktree) = try directories()
    try FileManager.default.createDirectory(
      at: repository.appending(path: "node_modules/left-pad"), withIntermediateDirectories: true)
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    try WorktreeFiles.place(".env\nnode_modules", as: .link, from: repository, to: worktree)

    let manager = FileManager.default
    for name in [".env", "node_modules"] {
      let attributes = try manager.attributesOfItem(atPath: worktree.appending(path: name).path)
      #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
      #expect(
        try manager.destinationOfSymbolicLink(atPath: worktree.appending(path: name).path)
          == repository.appending(path: name).path,
        "at the repository's own, by absolute path")
    }
    #expect(manager.fileExists(atPath: worktree.appending(path: "node_modules/left-pad").path))
    // In place, not atomically: an atomic write renames a new file over
    // the link and would say nothing about what the link points at.
    try "SECRET=2".write(to: worktree.appending(path: ".env"), atomically: false, encoding: .utf8)
    #expect(
      try String(contentsOf: repository.appending(path: ".env"), encoding: .utf8) == "SECRET=2",
      "and a write through the link is a write to the repository's file")
  }

  /// The lists run in this order and neither places anything over what is already there, which
  /// alone settles a path spelled in both.
  @Test func aPathInBothListsEndsUpTheLinkTheCopyRunsAfter() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    for placement in WorktreeFilePlacement.allCases {
      try WorktreeFiles.place(".env", as: placement, from: repository, to: worktree)
    }
    let attributes = try FileManager.default.attributesOfItem(
      atPath: worktree.appending(path: ".env").path)
    #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
  }

  /// git checks out a tracked symlink whether or not this branch carries its target, and placing
  /// over it would fail on it.
  @Test(arguments: WorktreeFilePlacement.allCases)
  func aDanglingSymlinkGitCheckedOutIsLeftAloneLikeAnyOtherFile(
    _ placement: WorktreeFilePlacement
  ) throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: worktree.appending(path: ".env"),
      withDestinationURL: worktree.appending(path: "not-on-this-branch"))

    try WorktreeFiles.place(".env", as: placement, from: repository, to: worktree)

    #expect(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: worktree.appending(path: ".env").path)
        == worktree.appending(path: "not-on-this-branch").path,
      "the worktree's own is untouched")
  }

  /// A copy under a linked folder would land in the repository through the link; the containment
  /// check is against the disk, so it catches that.
  @Test func aCopyUnderALinkedFolderIsRefusedRatherThanWrittenThroughTheLink() throws {
    let (repository, worktree) = try directories()
    try FileManager.default.createDirectory(
      at: repository.appending(path: "vendor"), withIntermediateDirectories: true)
    try "dep".write(to: repository.appending(path: "vendor/dep"), atomically: true, encoding: .utf8)

    try WorktreeFiles.place("vendor", as: .link, from: repository, to: worktree)
    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("vendor/dep", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["vendor/dep"])
  }

  /// The pane's Cancel, which has no process to signal: it lands between
  /// paths, and what is in the worktree by then stays there.
  @Test func aStopEndsTheListAtTheNextPathAndKeepsWhatIsPlaced() throws {
    let (repository, worktree) = try directories()
    try "one".write(to: repository.appending(path: ".env.local"), atomically: true, encoding: .utf8)
    try "two".write(to: repository.appending(path: ".env.test"), atomically: true, encoding: .utf8)
    // Sorted, so `.env.local` is placed first and its arrival is the stop.
    let placed = worktree.appending(path: ".env.local")

    #expect(throws: WorktreeFileStopped.self) {
      try WorktreeFiles.place(
        ".env.*", as: .copy, from: repository, to: worktree,
        isStopped: { FileManager.default.fileExists(atPath: placed.path) })
    }
    #expect(try String(contentsOf: placed, encoding: .utf8) == "one")
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(path: ".env.test").path))
  }

  /// Cancel excuses what it stopped, not what had already gone wrong: the
  /// stage used to be reported finished with the failures thrown away.
  @Test func aStopCarriesTheFailuresItAlreadyHad() throws {
    let (repository, worktree) = try directories()
    try FileManager.default.createDirectory(
      at: repository.appending(path: "vendor"), withIntermediateDirectories: true)
    try "dep".write(to: repository.appending(path: "vendor/dep"), atomically: true, encoding: .utf8)
    try "two".write(to: repository.appending(path: "after.txt"), atomically: true, encoding: .utf8)
    // A folder linked into the worktree, so writing through it is refused.
    try WorktreeFiles.place("vendor", as: .link, from: repository, to: worktree)

    // The stop lands after the first path, which is the one that failed.
    let seen = Counter()
    let stopped = #expect(throws: WorktreeFileStopped.self) {
      try WorktreeFiles.place(
        "vendor/dep\nafter.txt", as: .copy, from: repository, to: worktree,
        isStopped: { seen.next() > 0 })
    }

    #expect(stopped?.failures.map(\.path) == ["vendor/dep"])
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(path: "after.txt").path))
  }

  /// A leading `/` or `~` is not a way out: it lands under the repository,
  /// where there is nothing to copy, so it needs no rule of its own.
  @Test func anAbsolutePathOrATildeIsRefusedRatherThanFindingNothing() throws {
    let (repository, worktree) = try directories()
    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place(
        "/etc/passwd\n~/.ssh/id_rsa", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["/etc/passwd", "~/.ssh/id_rsa"])
    #expect(try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty)
  }

  @Test func copyingBringsFilesAndFoldersAcrossAndMakesTheDirectoriesTheyNeed() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(
      at: repository.appending(path: "config/local"), withIntermediateDirectories: true)
    try "port: 1".write(
      to: repository.appending(path: "config/local/dev.yml"), atomically: true, encoding: .utf8)

    try WorktreeFiles.place(".env\nconfig/local", as: .copy, from: repository, to: worktree)
    #expect(try String(contentsOf: worktree.appending(path: ".env"), encoding: .utf8) == "SECRET=1")
    #expect(
      try String(contentsOf: worktree.appending(path: "config/local/dev.yml"), encoding: .utf8)
        == "port: 1")
  }

  @Test func aPathTheRepositoryDoesNotHaveIsSkippedRatherThanFailing() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)
    try WorktreeFiles.place(".env\n.env.local", as: .copy, from: repository, to: worktree)
    #expect(FileManager.default.fileExists(atPath: worktree.appending(path: ".env").path))
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(path: ".env.local").path))
  }

  /// git checked the tracked file out; a copy over it would be the wrong
  /// branch's.
  @Test func aFileGitAlreadyPutInTheWorktreeIsLeftAlone() throws {
    let (repository, worktree) = try directories()
    try "trunk".write(
      to: repository.appending(path: "config.yml"), atomically: true, encoding: .utf8)
    try "branch".write(
      to: worktree.appending(path: "config.yml"), atomically: true, encoding: .utf8)
    try WorktreeFiles.place("config.yml", as: .copy, from: repository, to: worktree)
    #expect(
      try String(contentsOf: worktree.appending(path: "config.yml"), encoding: .utf8) == "branch")
  }

  @Test func aUsersOwnSkippedEntryStaysApartFromTheFailuresBesideIt() throws {
    let (repository, worktree) = try directories()
    try FileManager.default.createDirectory(
      at: repository.appending(path: "blocked"), withIntermediateDirectories: true)
    try "x".write(
      to: repository.appending(path: "blocked/inner"), atomically: true, encoding: .utf8)
    try "wall".write(to: worktree.appending(path: "blocked"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place(
        "blocked/inner\n~/.aws.json", as: .copy, from: repository, to: worktree,
        heldToRepository: false)
    }
    #expect(failure?.failures.map(\.path) == ["blocked/inner"])
    #expect(failure?.skipped == ["~/.aws.json"])
  }

  /// One path that cannot be copied should not cost the rest of the list.
  @Test func everythingCopiableIsCopiedAndTheFailuresAreNamedTogether() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(
      at: repository.appending(path: "blocked"), withIntermediateDirectories: true)
    try "x".write(
      to: repository.appending(path: "blocked/inner"), atomically: true, encoding: .utf8)
    // A file where the copy needs a directory, so making `blocked/` fails.
    try "wall".write(to: worktree.appending(path: "blocked"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("blocked/inner\n.env", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["blocked/inner"])
    #expect(FileManager.default.fileExists(atPath: worktree.appending(path: ".env").path))
  }

  /// A list a repository ships is not asked about first. The two links point apart, so the
  /// destination is somewhere new rather than a file already there.
  @Test func aSymlinkedFolderCannotDivertTheReadOrTheWrite() throws {
    let (repository, worktree) = try directories()
    let root = repository.deletingLastPathComponent()
    let read = root.appending(path: "elsewhere-read")
    let write = root.appending(path: "elsewhere-write")
    for url in [read, write] {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    try "TOP SECRET".write(to: read.appending(path: "key"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: repository.appending(path: "link"), withDestinationURL: read)
    try FileManager.default.createSymbolicLink(
      at: worktree.appending(path: "link"), withDestinationURL: write)

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("link/key", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["link/key"])
    #expect(
      !FileManager.default.fileExists(atPath: write.appending(path: "key").path),
      "nothing was written outside the worktree")
  }

  /// `copyItem` copies a link rather than following it, so the worktree would
  /// hold a pointer at whatever it names. See Docs/design/hooks.md.
  @Test(arguments: [WorktreeFilePlacement.copy, .link])
  func aSymlinkAtTheEndOfThePathIsRefusedLikeOneInTheMiddle(
    _ placement: WorktreeFilePlacement
  ) throws {
    let (repository, worktree) = try directories()
    let outside = repository.deletingLastPathComponent().appending(path: "outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "TOP SECRET".write(to: outside.appending(path: "real"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: repository.appending(path: ".env"), withDestinationURL: outside.appending(path: "real"))

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place(".env", as: placement, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == [".env"])
    #expect(try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty)
  }

  /// A symlink that stays inside is the ordinary case and is carried whole.
  @Test func aSymlinkThatStaysInsideTheRepositoryIsPlaced() throws {
    let (repository, worktree) = try directories()
    try "SECRET=1".write(
      to: repository.appending(path: ".env.real"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: repository.appending(path: ".env"),
      withDestinationURL: repository.appending(path: ".env.real"))

    try WorktreeFiles.place(".env", as: .copy, from: repository, to: worktree)

    #expect(try String(contentsOf: worktree.appending(path: ".env"), encoding: .utf8) == "SECRET=1")
  }

  /// A glob may not reach out either: it expands under the repository, and
  /// each name it finds is judged against the disk like any other.
  @Test func aGlobCannotExpandOntoSomethingOutsideTheRepository() throws {
    let (repository, worktree) = try directories()
    let outside = repository.deletingLastPathComponent().appending(path: "outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "TOP SECRET".write(to: outside.appending(path: "key"), atomically: true, encoding: .utf8)
    try "SECRET=1".write(to: repository.appending(path: "a.env"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: repository.appending(path: "b.env"), withDestinationURL: outside.appending(path: "key"))

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("*.env", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["b.env"])
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: worktree.path) == ["a.env"],
      "the one that stayed inside is still placed")
  }

  @Test func aPatternInAFolderNameExpandsToEachFolderThatMatches() throws {
    let (repository, worktree) = try directories()
    for pack in ["pack-a", "pack-b"] {
      try FileManager.default.createDirectory(
        at: repository.appending(path: pack), withIntermediateDirectories: true)
      try "x".write(
        to: repository.appending(path: "\(pack)/.env"), atomically: true, encoding: .utf8)
    }
    #expect(
      WorktreeFilePattern.expand("pack-?/.env", in: repository) == ["pack-a/.env", "pack-b/.env"])

    try WorktreeFiles.place("pack-*/.env", as: .copy, from: repository, to: worktree)
    #expect(FileManager.default.fileExists(atPath: worktree.appending(path: "pack-b/.env").path))
  }

  @Test func copyingBringsEveryFileAPatternMatches() throws {
    let (repository, worktree) = try directories()
    try "one".write(to: repository.appending(path: ".env.local"), atomically: true, encoding: .utf8)
    try "two".write(to: repository.appending(path: ".env.test"), atomically: true, encoding: .utf8)
    try WorktreeFiles.place(".env.*", as: .copy, from: repository, to: worktree)
    #expect(
      try String(contentsOf: worktree.appending(path: ".env.local"), encoding: .utf8) == "one")
    #expect(try String(contentsOf: worktree.appending(path: ".env.test"), encoding: .utf8) == "two")
  }

  /// Left behind, the half a Cancel stopped at read as placed: a later
  /// placement passes over anything already at the destination.
  @Test func aCancelEndsTheCopyOfALargeDirectoryPartWayAndTakesTheHalfAway() throws {
    let (repository, worktree) = try directories()
    let cache = repository.appending(path: "cache")
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    for index in 0..<200 {
      try "x".write(to: cache.appending(path: "f\(index)"), atomically: true, encoding: .utf8)
    }
    let asked = Counter()

    #expect(throws: WorktreeFileStopped.self) {
      try WorktreeFiles.place(
        "cache", as: .copy, from: repository, to: worktree,
        isStopped: { asked.next() > 20 })
    }

    #expect(!FileManager.default.fileExists(atPath: worktree.appending(path: "cache").path))
  }

  @Test func aStopCarriesTheEntriesItAlreadySkipped() throws {
    let (repository, worktree) = try directories()
    try "one".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    let stopped = #expect(throws: WorktreeFileStopped.self) {
      try WorktreeFiles.place(
        "~/.aws.json\n.env", as: .copy, from: repository, to: worktree,
        heldToRepository: false, isStopped: { true })
    }

    #expect(stopped?.skipped == ["~/.aws.json"])
  }

  @Test func aCopiedDirectoryArrivesWholeDownToItsNestedFilesAndLinks() throws {
    let (repository, worktree) = try directories()
    let cache = repository.appending(path: "cache/deep/er")
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    try "x".write(to: cache.appending(path: "file.txt"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      atPath: cache.appending(path: "link").path, withDestinationPath: "file.txt")

    try WorktreeFiles.place("cache", as: .copy, from: repository, to: worktree)

    let copied = worktree.appending(path: "cache/deep/er")
    #expect(try String(contentsOf: copied.appending(path: "file.txt"), encoding: .utf8) == "x")
    #expect(
      try FileManager.default.destinationOfSymbolicLink(atPath: copied.appending(path: "link").path)
        == "file.txt")
  }

  @Test func aReadOnlyDirectoryIsCopiedWholeAndKeepsItsMode() throws {
    let (repository, worktree) = try directories()
    let inner = repository.appending(path: "modules/inner")
    try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
    try "x".write(to: inner.appending(path: "file.txt"), atomically: true, encoding: .utf8)
    let copied = worktree.appending(path: "modules")
    let readOnly = [inner, repository.appending(path: "modules")]
    for directory in readOnly {
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o555], ofItemAtPath: directory.path)
    }
    defer {
      for directory in readOnly.reversed() + [copied, copied.appending(path: "inner")] {
        try? FileManager.default.setAttributes(
          [.posixPermissions: 0o755], ofItemAtPath: directory.path)
      }
    }

    try WorktreeFiles.place("modules", as: .copy, from: repository, to: worktree)

    #expect(
      try String(contentsOf: copied.appending(path: "inner/file.txt"), encoding: .utf8) == "x")
    for directory in [copied, copied.appending(path: "inner")] {
      let mode = try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions]
      #expect(mode as? Int == 0o555)
    }
  }

  @Test func aFolderInsideACopiedDirectoryThatCannotBeReadFailsTheEntry() throws {
    let (repository, worktree) = try directories()
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
    let (repository, worktree) = try directories()
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

  private func directories() throws -> (repository: URL, worktree: URL) {
    let repository = root.appending(path: "repo")
    let worktree = root.appending(path: "tree")
    for url in [repository, worktree] {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return (repository, worktree)
  }
}

/// A `@Sendable` counter, `isStopped` being called from a closure that
/// cannot capture a mutable local.
private final class Counter: Sendable {
  private let value = Atomic(0)

  func next() -> Int {
    value.wrappingAdd(1, ordering: .relaxed).oldValue
  }
}

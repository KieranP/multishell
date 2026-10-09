import Foundation
import Testing

@testable import MultishellGitKit

extension WorktreeFilesTests {
  /// Containment is decided against the disk, not the spelling, so a `..` is refused by name
  /// rather than dropped, and a link is no way around it.
  @Test(arguments: WorktreeFilePlacement.allCases)
  func aPathThatReachesOutsideTheRepositoryIsRefused(_ placement: WorktreeFilePlacement) throws {
    let (repository, worktree) = try repositoryAndWorktree()
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
      "and nothing was placed in the worktree",
    )
  }

  /// The rule holds a repository to the checkout, not the user: a path they
  /// typed into project settings is used as written. See settings.md.
  @Test(arguments: [WorktreeFilePlacement.copy, .link])
  func aPathTheUserListedThemselvesIsNotHeldToTheCheckout(_ placement: WorktreeFilePlacement) throws
  {
    let (repository, worktree) = try repositoryAndWorktree()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    let skipped = try WorktreeFiles.place(
      "~/.aws.json\n$HOME/.zshrc\n/etc/passwd\n.env",
      as: placement,
      from: repository,
      to: worktree,
      isRepositoryList: false,
    )

    #expect(try FileManager.default.contentsOfDirectory(atPath: worktree.path) == [".env"])
    #expect(skipped == ["~/.aws.json", "$HOME/.zshrc", "/etc/passwd"])
  }

  /// The destination is mirrored from the entry rather than asked for, so
  /// even a list of the user's own places nothing outside the worktree.
  @Test func aUsersOwnEntryIsNeverPlacedOutsideTheWorktree() throws {
    let (repository, _) = try repositoryAndWorktree()
    let manager = FileManager.default
    let worktree = root.appending(path: "trees/w")
    let outside = root.appending(path: "outside")
    for url in [worktree, outside] {
      try manager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    try "TOP SECRET".write(to: outside.appending(path: "key"), atomically: true, encoding: .utf8)

    let skipped = try WorktreeFiles.place(
      "../outside/key",
      as: .copy,
      from: repository,
      to: worktree,
      isRepositoryList: false,
    )

    #expect(skipped == ["../outside/key"])
    #expect(try manager.contentsOfDirectory(atPath: worktree.path).isEmpty)
    #expect(
      !manager.fileExists(atPath: root.appending(path: "trees/outside/key").path),
      "and nothing was written beside it either",
    )
  }

  /// Refused, not silently skipped: these used to fail only because
  /// `repo/~/.aws.json` does not exist, which is luck.
  @Test(arguments: [WorktreeFilePlacement.copy, .link])
  func noSpellingOfAPathOutsideTheRepositoryIsPlaced(_ placement: WorktreeFilePlacement) throws {
    let (repository, worktree) = try repositoryAndWorktree()
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
    let (repository, worktree) = try repositoryAndWorktree()
    try "SECRET=1".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place(
        ".env\n~/.aws.json",
        as: .copy,
        from: repository,
        to: worktree,
      )
    }
    #expect(failure?.failures.map(\.path) == ["~/.aws.json"])
    #expect(
      try String(contentsOf: worktree.appending(path: ".env"), encoding: .utf8) == "SECRET=1"
    )
  }

  /// A copy under a linked folder would land in the repository through the link; the containment
  /// check is against the disk, so it catches that.
  @Test func aCopyUnderALinkedFolderIsRefusedRatherThanWrittenThroughTheLink() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try FileManager.default.createDirectory(
      at: repository.appending(path: "vendor"),
      withIntermediateDirectories: true,
    )
    try "dep".write(
      to: repository.appending(path: "vendor/dep"),
      atomically: true,
      encoding: .utf8,
    )

    try WorktreeFiles.place("vendor", as: .link, from: repository, to: worktree)
    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("vendor/dep", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["vendor/dep"])
  }

  /// A leading `/` or `~` is not a way out: it lands under the repository,
  /// where there is nothing to copy, so it needs no rule of its own.
  @Test func anAbsolutePathOrATildeIsRefusedRatherThanFindingNothing() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place(
        "/etc/passwd\n~/.ssh/id_rsa",
        as: .copy,
        from: repository,
        to: worktree,
      )
    }
    #expect(failure?.failures.map(\.path) == ["/etc/passwd", "~/.ssh/id_rsa"])
    #expect(try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty)
  }

  /// A list a repository ships is not asked about first. The two links point apart, so the
  /// destination is somewhere new rather than a file already there.
  @Test func aSymlinkedFolderCannotDivertTheReadOrTheWrite() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    let root = repository.deletingLastPathComponent()
    let read = root.appending(path: "elsewhere-read")
    let write = root.appending(path: "elsewhere-write")
    for url in [read, write] {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    try "TOP SECRET".write(to: read.appending(path: "key"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: repository.appending(path: "link"),
      withDestinationURL: read,
    )
    try FileManager.default.createSymbolicLink(
      at: worktree.appending(path: "link"),
      withDestinationURL: write,
    )

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place("link/key", as: .copy, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == ["link/key"])
    #expect(
      !FileManager.default.fileExists(atPath: write.appending(path: "key").path),
      "nothing was written outside the worktree",
    )
  }

  /// `copyItem` copies a link rather than following it, so the worktree would
  /// hold a pointer at whatever it names. See Docs/design/hooks.md.
  @Test(arguments: [WorktreeFilePlacement.copy, .link])
  func aSymlinkAtTheEndOfThePathIsRefusedLikeOneInTheMiddle(
    _ placement: WorktreeFilePlacement
  ) throws {
    let (repository, worktree) = try repositoryAndWorktree()
    let outside = repository.deletingLastPathComponent().appending(path: "outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "TOP SECRET".write(to: outside.appending(path: "real"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: repository.appending(path: ".env"),
      withDestinationURL: outside.appending(path: "real"),
    )

    let failure = #expect(throws: WorktreeFileFailure.self) {
      try WorktreeFiles.place(".env", as: placement, from: repository, to: worktree)
    }
    #expect(failure?.failures.map(\.path) == [".env"])
    #expect(try FileManager.default.contentsOfDirectory(atPath: worktree.path).isEmpty)
  }

  @Test func aSymlinkThatStaysInsideTheRepositoryIsPlaced() throws {
    let (repository, worktree) = try repositoryAndWorktree()
    try "SECRET=1".write(
      to: repository.appending(path: ".env.real"),
      atomically: true,
      encoding: .utf8,
    )
    try FileManager.default.createSymbolicLink(
      at: repository.appending(path: ".env"),
      withDestinationURL: repository.appending(path: ".env.real"),
    )

    try WorktreeFiles.place(".env", as: .copy, from: repository, to: worktree)

    #expect(
      try String(contentsOf: worktree.appending(path: ".env"), encoding: .utf8) == "SECRET=1"
    )
  }
}

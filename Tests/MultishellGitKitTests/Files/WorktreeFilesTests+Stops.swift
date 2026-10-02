import Foundation
import Testing

@testable import MultishellGitKit

extension WorktreeFilesTests {
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
        isStopRequested: { FileManager.default.fileExists(atPath: placed.path) })
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
    let seen = CallCounter()
    let stopped = #expect(throws: WorktreeFileStopped.self) {
      try WorktreeFiles.place(
        "vendor/dep\nafter.txt", as: .copy, from: repository, to: worktree,
        isStopRequested: { seen.next() > 0 })
    }

    #expect(stopped?.failures.map(\.path) == ["vendor/dep"])
    #expect(!FileManager.default.fileExists(atPath: worktree.appending(path: "after.txt").path))
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
    let asked = CallCounter()

    #expect(throws: WorktreeFileStopped.self) {
      try WorktreeFiles.place(
        "cache", as: .copy, from: repository, to: worktree,
        isStopRequested: { asked.next() > 20 })
    }

    #expect(!FileManager.default.fileExists(atPath: worktree.appending(path: "cache").path))
  }

  @Test func aStopCarriesTheEntriesItAlreadySkipped() throws {
    let (repository, worktree) = try directories()
    try "one".write(to: repository.appending(path: ".env"), atomically: true, encoding: .utf8)

    let stopped = #expect(throws: WorktreeFileStopped.self) {
      try WorktreeFiles.place(
        "~/.aws.json\n.env", as: .copy, from: repository, to: worktree,
        isRepositoryList: false, isStopRequested: { true })
    }

    #expect(stopped?.skipped == ["~/.aws.json"])
  }
}

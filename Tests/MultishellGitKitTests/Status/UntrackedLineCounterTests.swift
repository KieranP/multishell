import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
struct UntrackedLineCounterTests {
  @Test func countsLinesOfEachListedFile() throws {
    let root = try Scratch.directory("untracked")
    defer { Scratch.remove(root) }
    try "a\nb\nc\n".write(
      to: root.appendingPathComponent("one.txt"), atomically: true, encoding: .utf8)
    try "d\ne".write(to: root.appendingPathComponent("two.txt"), atomically: true, encoding: .utf8)

    let counted = UntrackedLineCounter.count(paths: ["one.txt", "two.txt"], in: root)
    #expect(counted.insertions == 5)
    #expect(counted.unscored == 0)
  }

  @Test func aFileUnchangedSinceTheLastCountIsNotReadAgain() throws {
    let root = try Scratch.directory("untracked")
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o644], ofItemAtPath: root.appendingPathComponent("one.txt").path)
      Scratch.remove(root)
    }
    let file = root.appendingPathComponent("one.txt")
    try "a\nb\n".write(to: file, atomically: true, encoding: .utf8)
    let memo = UntrackedLineMemo()
    _ = UntrackedLineCounter.count(paths: ["one.txt"], in: root, memo: memo)
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)

    let counted = UntrackedLineCounter.count(paths: ["one.txt"], in: root, memo: memo)

    #expect(counted.insertions == 2, "the unreadable file was not read")
    #expect(counted.unscored == 0)
  }

  @Test func aFileRewrittenToANewSizeIsCountedAgain() throws {
    let root = try Scratch.directory("untracked")
    defer { Scratch.remove(root) }
    let file = root.appendingPathComponent("one.txt")
    try "a\n".write(to: file, atomically: true, encoding: .utf8)
    let memo = UntrackedLineMemo()
    _ = UntrackedLineCounter.count(paths: ["one.txt"], in: root, memo: memo)
    try "a\nb\nc\n".write(to: file, atomically: true, encoding: .utf8)

    #expect(UntrackedLineCounter.count(paths: ["one.txt"], in: root, memo: memo).insertions == 3)
  }

  @Test func aBinaryFileAndAMissingOneCountAsFilesWithNoLines() throws {
    let root = try Scratch.directory("untracked")
    defer { Scratch.remove(root) }
    try Data([0x89, 0x50, 0x00, 0x0A, 0x0A]).write(to: root.appendingPathComponent("icon.png"))

    let counted = UntrackedLineCounter.count(paths: ["icon.png", "gone.txt"], in: root)
    #expect(counted.insertions == 0)
    #expect(counted.unscored == 2, "a new png and a path that went away both still changed")
  }

  /// `git worktree list` says nothing about the URL being a directory, and a
  /// base not marked as one resolves a relative path against its parent.
  @Test func aPathResolvesUnderADirectoryUrlNotMarkedAsOne() throws {
    let root = try Scratch.directory("untracked")
    defer { Scratch.remove(root) }
    try "a\nb\n".write(
      to: root.appendingPathComponent("one.txt"), atomically: true, encoding: .utf8)
    let unmarked = URL(fileURLWithPath: root.path, isDirectory: false)

    #expect(UntrackedLineCounter.count(paths: ["one.txt"], in: unmarked).insertions == 2)
  }

  @Test func anEmptyFileCountsNoLine() throws {
    let root = try Scratch.directory("untracked")
    defer { Scratch.remove(root) }
    try Data().write(to: root.appendingPathComponent("empty.txt"))

    let counted = UntrackedLineCounter.count(paths: ["empty.txt"], in: root)
    #expect(counted.insertions == 0 && counted.unscored == 1)
  }

  /// `.fileSizeKey` is the link's own bytes while the read follows it, so a
  /// link into a large file passed the cap and then took the whole budget.
  @Test func aSymlinkIsCountedAsAFileAndNeverFollowed() throws {
    let root = try Scratch.directory("untracked")
    defer { Scratch.remove(root) }
    let target = root.appendingPathComponent("target.txt")
    try "a\nb\nc\n".write(to: target, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: root.appendingPathComponent("link.txt"), withDestinationURL: target)

    let counted = UntrackedLineCounter.count(paths: ["link.txt"], in: root)
    #expect(counted.insertions == 0, "git stores the link, not the lines it points at")
    #expect(counted.unscored == 1)
  }

  @Test func aFileThatWouldCrossTheTotalBudgetIsSkippedAndTheRestAreStillCounted() throws {
    let root = try Scratch.directory("untracked")
    defer { Scratch.remove(root) }
    func write(_ name: String, bytes: Int) throws {
      try String(repeating: "x\n", count: bytes / 2).write(
        to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    let full = UntrackedLineCounter.totalByteLimit / UntrackedLineCounter.byteLimit - 1
    for index in 0..<full { try write("\(index).txt", bytes: UntrackedLineCounter.byteLimit) }
    let headroom = UntrackedLineCounter.totalByteLimit - full * UntrackedLineCounter.byteLimit
    try write("nearly-full.txt", bytes: headroom - 2048)
    try write("crosses.txt", bytes: 4096)
    try write("after.txt", bytes: 4)

    let counted = UntrackedLineCounter.count(
      paths: (0..<full).map { "\($0).txt" } + ["nearly-full.txt", "crosses.txt", "after.txt"],
      in: root)

    let counting = full * UntrackedLineCounter.byteLimit + headroom - 2048 + 4
    #expect(counted.insertions == counting / 2)
    #expect(counted.unscored == 1, "the file that would not fit, and not the small one after it")
  }

  @Test func aFileThatCouldNotBeReadLeavesTheBudgetToTheRest() throws {
    let root = try Scratch.directory("untracked")
    let full = UntrackedLineCounter.totalByteLimit / UntrackedLineCounter.byteLimit
    let unreadable = (0..<full).map { root.appendingPathComponent("locked\($0).txt") }
    defer {
      for file in unreadable {
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
      }
      Scratch.remove(root)
    }
    for file in unreadable {
      try String(repeating: "x\n", count: UntrackedLineCounter.byteLimit / 2).write(
        to: file, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
    }
    try "a\nb\n".write(
      to: root.appendingPathComponent("after.txt"), atomically: true, encoding: .utf8)

    let counted = UntrackedLineCounter.count(
      paths: unreadable.map(\.lastPathComponent) + ["after.txt"], in: root)

    #expect(counted.insertions == 2)
    #expect(counted.unscored == full)
  }

  /// Counted as files with no lines, a directory nobody had gitignored put
  /// `~29500` beside the one untracked entry git status reports for it.
  @Test func theFilesPastTheFileCapAreNotCountedAtAll() throws {
    let root = try Scratch.directory("untracked")
    defer { Scratch.remove(root) }
    for index in 0..<(UntrackedLineCounter.fileLimit + 20) {
      try "a\n".write(
        to: root.appendingPathComponent("\(index).txt"), atomically: true, encoding: .utf8)
    }

    let counted = UntrackedLineCounter.count(
      paths: (0..<(UntrackedLineCounter.fileLimit + 20)).map { "\($0).txt" }, in: root)

    #expect(counted.insertions == UntrackedLineCounter.fileLimit)
    #expect(counted.unscored == 0)
  }
}

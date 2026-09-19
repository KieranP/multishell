import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
struct UntrackedLineCounterTests {
  private func directory() throws -> URL {
    let root = Scratch.path("untracked")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  @Test func countsLinesOfEachListedFile() throws {
    let root = try directory()
    defer { try? FileManager.default.removeItem(at: root) }
    try "a\nb\nc\n".write(
      to: root.appendingPathComponent("one.txt"), atomically: true, encoding: .utf8)
    try "d\ne".write(to: root.appendingPathComponent("two.txt"), atomically: true, encoding: .utf8)

    let counted = UntrackedLineCounter.count(paths: ["one.txt", "two.txt"], in: root)
    #expect(counted.lines == 5)
    #expect(counted.unscored == 0)
  }

  @Test func aBinaryFileAndAMissingOneCountAsFilesWithNoLines() throws {
    let root = try directory()
    defer { try? FileManager.default.removeItem(at: root) }
    try Data([0x89, 0x50, 0x00, 0x0A, 0x0A]).write(to: root.appendingPathComponent("icon.png"))

    let counted = UntrackedLineCounter.count(paths: ["icon.png", "gone.txt"], in: root)
    #expect(counted.lines == 0)
    #expect(counted.unscored == 2, "a new png and a path that went away both still changed")
  }

  /// `git worktree list` says nothing about the URL being a directory, and a
  /// base not marked as one resolves a relative path against its parent.
  @Test func aPathResolvesUnderADirectoryUrlNotMarkedAsOne() throws {
    let root = try directory()
    defer { try? FileManager.default.removeItem(at: root) }
    try "a\nb\n".write(
      to: root.appendingPathComponent("one.txt"), atomically: true, encoding: .utf8)
    let unmarked = URL(fileURLWithPath: root.path, isDirectory: false)

    #expect(UntrackedLineCounter.count(paths: ["one.txt"], in: unmarked).lines == 2)
  }

  @Test func anEmptyFileCountsNoLine() throws {
    let root = try directory()
    defer { try? FileManager.default.removeItem(at: root) }
    try Data().write(to: root.appendingPathComponent("empty.txt"))

    let counted = UntrackedLineCounter.count(paths: ["empty.txt"], in: root)
    #expect(counted.lines == 0 && counted.unscored == 1)
  }

  @Test func pathsAreSplitOnNulAndNotOnNewlines() {
    #expect(UntrackedLineCounter.paths(from: "a.txt\0dir/b c.txt\0") == ["a.txt", "dir/b c.txt"])
    #expect(UntrackedLineCounter.paths(from: "odd\nname.txt\0") == ["odd\nname.txt"])
    #expect(UntrackedLineCounter.paths(from: "").isEmpty)
  }

  /// `.fileSizeKey` is the link's own bytes while the read follows it, so a
  /// link into a large file passed the cap and then took the whole budget.
  @Test func aSymlinkIsCountedAsAFileAndNeverFollowed() throws {
    let root = try directory()
    defer { try? FileManager.default.removeItem(at: root) }
    let target = root.appendingPathComponent("target.txt")
    try "a\nb\nc\n".write(to: target, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: root.appendingPathComponent("link.txt"), withDestinationURL: target)

    let counted = UntrackedLineCounter.count(paths: ["link.txt"], in: root)
    #expect(counted.lines == 0, "git stores the link, not the lines it points at")
    #expect(counted.unscored == 1)
  }

  @Test func aFileThatWouldCrossTheTotalBudgetIsSkippedAndTheRestAreStillCounted() throws {
    let root = try directory()
    defer { try? FileManager.default.removeItem(at: root) }
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
    #expect(counted.lines == counting / 2)
    #expect(counted.unscored == 1, "the file that would not fit, and not the small one after it")
  }

  @Test func onlyTheFilesItWillReadAreDecoded() {
    let listing = (1...UntrackedLineCounter.fileLimit + 3).map { "f\($0).txt" }
      .joined(separator: "\0")

    #expect(UntrackedLineCounter.paths(from: listing).count == UntrackedLineCounter.fileLimit)
  }

  /// Counted as files with no lines, a directory nobody had gitignored put
  /// `~29500` beside the one untracked entry git status reports for it.
  @Test func theFilesPastTheFileCapAreNotCountedAtAll() throws {
    let root = try directory()
    defer { try? FileManager.default.removeItem(at: root) }
    for index in 0..<(UntrackedLineCounter.fileLimit + 20) {
      try "a\n".write(
        to: root.appendingPathComponent("\(index).txt"), atomically: true, encoding: .utf8)
    }

    let counted = UntrackedLineCounter.count(
      paths: (0..<(UntrackedLineCounter.fileLimit + 20)).map { "\($0).txt" }, in: root)

    #expect(counted.lines == UntrackedLineCounter.fileLimit)
    #expect(counted.unscored == 0)
  }
}

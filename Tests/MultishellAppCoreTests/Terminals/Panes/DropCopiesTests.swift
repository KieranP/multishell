import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct DropCopiesTests {
  private func drop(_ name: String, in parent: URL, modified: Date) throws -> URL {
    let directory = parent.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data().write(to: directory.appendingPathComponent("shot.png"))
    try FileManager.default.setAttributes(
      [.modificationDate: modified],
      ofItemAtPath: directory.path,
    )
    return directory
  }

  @Test func eachDragGetsItsOwnDirectorySoTwoOfANameCannotCollide() throws {
    let parent = try Scratch.directory("drops")
    defer { Scratch.remove(parent) }

    let one = try DropCopies.makeDirectory(in: parent)
    let two = try DropCopies.makeDirectory(in: parent)
    #expect(one != two)
    #expect(FileManager.default.fileExists(atPath: one.path))
    #expect(FileManager.default.fileExists(atPath: two.path))
  }

  @Test func theFirstDragMakesTheDirectoryItself() throws {
    let parent = Scratch.path("drops")
    defer { Scratch.remove(parent) }
    #expect(!FileManager.default.fileExists(atPath: parent.path))

    let directory = try DropCopies.makeDirectory(in: parent)

    #expect(FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func aSweepTakesTheDragsPastKeepingAndLeavesTheRest() throws {
    let parent = try Scratch.directory("drops")
    defer { Scratch.remove(parent) }
    let now = Date()
    let old = try drop("old", in: parent, modified: now.addingTimeInterval(-8 * 24 * 60 * 60))
    let recent = try drop("recent", in: parent, modified: now.addingTimeInterval(-60))

    DropCopies.sweep(in: parent, keeping: DropCopies.retention, now: now)

    #expect(!FileManager.default.fileExists(atPath: old.path))
    #expect(FileManager.default.fileExists(atPath: recent.path))
  }

  @Test func aKeptDropIsSweptOnlyOnceRetentionHasPassedSinceItWasKept() throws {
    let parent = try Scratch.directory("drops")
    defer { Scratch.remove(parent) }
    let now = Date()
    let drop = try drop("kept", in: parent, modified: now.addingTimeInterval(-8 * 24 * 60 * 60))

    DropCopies.keep(drop)
    DropCopies.sweep(in: parent, now: now.addingTimeInterval(6 * 24 * 60 * 60))
    #expect(FileManager.default.fileExists(atPath: drop.path))
    DropCopies.sweep(in: parent, now: now.addingTimeInterval(8 * 24 * 60 * 60))
    #expect(!FileManager.default.fileExists(atPath: drop.path))
  }

  @Test func aRemovedDropIsGone() throws {
    let parent = try Scratch.directory("drops")
    defer { Scratch.remove(parent) }
    let drop = try drop("unused", in: parent, modified: Date())

    DropCopies.remove(drop)

    #expect(!FileManager.default.fileExists(atPath: drop.path))
  }

  /// Nothing to sweep is not a failure: the directory is made by the first
  /// drag or paste that needs one, and most launches come before one.
  @Test func aSweepOfADirectoryThatIsNotThereDoesNothing() {
    let missing = Scratch.path("drops")
    DropCopies.sweep(in: missing)
    #expect(!FileManager.default.fileExists(atPath: missing.path))
  }
}

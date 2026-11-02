import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

/// Each clone here fails, as it does on another volume or a disk not APFS,
/// so the walk `copy` falls back to is what runs.
@Suite
final class WorktreeFileCopyTests {
  let root = Scratch.path("file-copy")

  @Test func aDirectoryTheCloneCannotTakeIsWalkedAcrossWholeWithItsLinksKept() throws {
    let source = root.appending(path: "cache")
    let deep = source.appending(path: "deep/er")
    try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
      at: source.appending(path: "empty"),
      withIntermediateDirectories: true,
    )
    try "x".write(to: deep.appending(path: "file.txt"), atomically: true, encoding: .utf8)
    try "y".write(to: source.appending(path: ".hidden"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      atPath: deep.appending(path: "link").path,
      withDestinationPath: "file.txt",
    )
    let destination = root.appending(path: "copied")
    let cloned = CallCounter()

    try WorktreeFileCopy.copy(
      source,
      to: destination,
      isStopRequested: { false },
      clone: { _, _ in
        _ = cloned.next()
        return false
      },
    )

    #expect(cloned.next() == 1)
    let copiedDeep = destination.appending(path: "deep/er")
    #expect(try String(contentsOf: copiedDeep.appending(path: "file.txt"), encoding: .utf8) == "x")
    #expect(
      try String(contentsOf: destination.appending(path: ".hidden"), encoding: .utf8) == "y"
    )
    #expect(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: copiedDeep.appending(path: "link").path
      ) == "file.txt"
    )
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: destination.appending(path: "empty").path)
        .isEmpty
    )
  }

  @Test func aSingleFileIsCopiedWithoutAskingForAClone() throws {
    let source = root.appending(path: ".env")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "SECRET=1".write(to: source, atomically: true, encoding: .utf8)
    let destination = root.appending(path: ".env.copied")
    let cloned = CallCounter()

    try WorktreeFileCopy.copy(
      source,
      to: destination,
      isStopRequested: { false },
      clone: { _, _ in
        _ = cloned.next()
        return false
      },
    )

    #expect(cloned.next() == 0)
    #expect(try String(contentsOf: destination, encoding: .utf8) == "SECRET=1")
  }

  /// Left behind, the half a Cancel stopped at read as placed: a later
  /// placement passes over anything already at the destination.
  @Test func aCancelEndsTheWalkOfALargeDirectoryPartWayAndTakesTheHalfAway() throws {
    let source = root.appending(path: "cache")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    for index in 0..<200 {
      try "x".write(to: source.appending(path: "f\(index)"), atomically: true, encoding: .utf8)
    }
    let destination = root.appending(path: "copied")
    let asked = CallCounter()

    #expect(throws: WorktreeFileStopped.self) {
      try WorktreeFileCopy.copy(
        source,
        to: destination,
        isStopRequested: { asked.next() > 20 },
        clone: { _, _ in false },
      )
    }

    #expect(!FileManager.default.fileExists(atPath: destination.path))
  }

  @Test func theWalkGivesAReadOnlyDirectoryItsModeOnceItsChildrenAreIn() throws {
    let source = root.appending(path: "modules")
    let inner = source.appending(path: "inner")
    try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
    try "x".write(to: inner.appending(path: "file.txt"), atomically: true, encoding: .utf8)
    let destination = root.appending(path: "copied")
    let readOnly = [inner, source, destination.appending(path: "inner"), destination]
    for directory in [inner, source] {
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o555],
        ofItemAtPath: directory.path,
      )
    }
    defer {
      for directory in readOnly {
        try? FileManager.default.setAttributes(
          [.posixPermissions: 0o755],
          ofItemAtPath: directory.path,
        )
      }
    }

    try WorktreeFileCopy.copy(
      source,
      to: destination,
      isStopRequested: { false },
      clone: { _, _ in false },
    )

    #expect(
      try String(contentsOf: destination.appending(path: "inner/file.txt"), encoding: .utf8) == "x"
    )
    for directory in [destination, destination.appending(path: "inner")] {
      let mode = try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions]
      #expect(mode as? Int == 0o555)
    }
  }

  deinit { Scratch.remove(root) }
}

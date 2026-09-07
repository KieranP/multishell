import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct DroppedFilesTests {
  private func makeParent() throws -> URL {
    let parent = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-drops-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    return parent
  }

  private func drop(_ name: String, in parent: URL, modified: Date) throws -> URL {
    let directory = parent.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data().write(to: directory.appendingPathComponent("shot.png"))
    try FileManager.default.setAttributes(
      [.modificationDate: modified], ofItemAtPath: directory.path)
    return directory
  }

  @Test func eachDragGetsItsOwnDirectorySoTwoOfANameCannotCollide() throws {
    let parent = try makeParent()
    defer { try? FileManager.default.removeItem(at: parent) }

    let one = try DroppedFiles.makeDirectory(in: parent)
    let two = try DroppedFiles.makeDirectory(in: parent)
    #expect(one != two)
    #expect(FileManager.default.fileExists(atPath: one.path))
    #expect(FileManager.default.fileExists(atPath: two.path))
  }

  /// The copy a drag hands over is the one this app alone may read, so it has
  /// to be told from a file the user has: the first is asked for again
  /// through its promise, the second keeps the path it is at.
  @Test func theCopyMacOSMakesForADropIsToldFromTheUsersOwnFile() {
    let temporary = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let copy =
      temporary
      .appendingPathComponent("TemporaryItems", isDirectory: true)
      .appendingPathComponent("NSIRD_screencaptureui_YGSj8h", isDirectory: true)
      .appendingPathComponent("Screenshot 2026-09-07 at 3.31.01 PM.png")
    #expect(DroppedFiles.isTemporaryCopy(copy))

    #expect(!DroppedFiles.isTemporaryCopy(URL(fileURLWithPath: "/Users/x/Desktop/Shot.png")))
    #expect(!DroppedFiles.isTemporaryCopy(URL(fileURLWithPath: "/repos/demo/Sources/App.swift")))
  }

  /// The name a copy carries is enough on its own, since a copy put outside
  /// the temporary directory is still one.
  @Test func aCopyNamedForItsSourceIsOneWhereverItWasPut() {
    let copy = URL(fileURLWithPath: "/somewhere/NSIRD_Mail_A1B2/Attachment.pdf")
    #expect(DroppedFiles.isTemporaryCopy(copy))
  }

  /// A directory of the user's own that happens to be called `TemporaryItems`
  /// is theirs, and a file in it keeps its path.
  @Test func aFolderOfTheUsersOwnCalledTemporaryItemsIsNotTheDragsCopy() {
    let mine = URL(fileURLWithPath: "/Users/x/TemporaryItems/notes.md")
    #expect(!DroppedFiles.isTemporaryCopy(mine))
  }

  /// A drag with no path at all is one whose files are not written yet —
  /// dragged out of Photos, or off a mail message — and the promise is the
  /// only thing there is to ask. Reading its paths as enough would refuse the
  /// drop after the pane had offered it.
  @Test func aDragOfferingNoPathAtAllIsOneToAskThePromiseFor() {
    #expect(DroppedFiles.needsPromise(for: []))
  }

  /// A copy among them is asked for again; paths the user's own are enough.
  @Test func onlyADragCarryingACopyNeedsThePromiseAsked() {
    let mine = URL(fileURLWithPath: "/Users/x/Desktop/Notes.md")
    let copy = URL(fileURLWithPath: "/somewhere/NSIRD_screencaptureui_A1/Shot.png")

    #expect(!DroppedFiles.needsPromise(for: [mine]))
    #expect(DroppedFiles.needsPromise(for: [copy]))
    #expect(DroppedFiles.needsPromise(for: [mine, copy]))
  }

  /// A drag of both kinds at once keeps the user's own files, which the drop
  /// pastes at once; the copies among them are asked for again through the
  /// promise, and a drop that took only the promised ones would lose these.
  @Test func aDragOfBothKindsKeepsTheFilesTheUserHas() {
    let mine = URL(fileURLWithPath: "/Users/x/Desktop/Notes.md")
    let copy = URL(fileURLWithPath: "/somewhere/NSIRD_screencaptureui_A1/Shot.png")

    #expect(DroppedFiles.own(among: [mine, copy]) == [mine])
    #expect(DroppedFiles.own(among: [copy]).isEmpty)
    #expect(DroppedFiles.own(among: [mine]) == [mine])
    #expect(DroppedFiles.own(among: []).isEmpty)
  }

  /// Nothing makes the drops directory before the first drop needs it, and a
  /// drop that could not make it delivers nothing at all.
  @Test func theFirstDragMakesTheDirectoryItself() throws {
    let parent = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-drops-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: parent) }
    #expect(!FileManager.default.fileExists(atPath: parent.path))

    let directory = try DroppedFiles.makeDirectory(in: parent)

    #expect(FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func aSweepTakesTheDragsPastKeepingAndLeavesTheRest() throws {
    let parent = try makeParent()
    defer { try? FileManager.default.removeItem(at: parent) }
    let now = Date()
    let old = try drop("old", in: parent, modified: now.addingTimeInterval(-8 * 24 * 60 * 60))
    let recent = try drop("recent", in: parent, modified: now.addingTimeInterval(-60))

    DroppedFiles.sweep(in: parent, keeping: DroppedFiles.keep, now: now)

    #expect(!FileManager.default.fileExists(atPath: old.path))
    #expect(FileManager.default.fileExists(atPath: recent.path))
  }

  /// Nothing to sweep is not a failure: the directory is made by the first
  /// promised drag, and most launches come before one.
  @Test func aSweepOfADirectoryThatIsNotThereDoesNothing() {
    let missing = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-drops-\(UUID().uuidString)", isDirectory: true)
    DroppedFiles.sweep(in: missing)
    #expect(!FileManager.default.fileExists(atPath: missing.path))
  }
}

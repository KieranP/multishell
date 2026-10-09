import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct DraggedFilePathsTests {
  /// Only this app may read the copy a drag hands over, so it is asked for again through its
  /// promise, while a file the user has keeps its path.
  @Test func theCopyMacOSMakesForADropIsToldFromTheUsersOwnFile() {
    let temporary = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let copy =
      temporary
      .appendingPathComponent("TemporaryItems", isDirectory: true)
      .appendingPathComponent("NSIRD_screencaptureui_YGSj8h", isDirectory: true)
      .appendingPathComponent("Screenshot 2026-09-07 at 3.31.01 PM.png")
    #expect(DraggedFilePaths.isTemporaryCopy(copy))

    #expect(!DraggedFilePaths.isTemporaryCopy(URL(fileURLWithPath: "/Users/x/Desktop/Shot.png")))
    #expect(
      !DraggedFilePaths.isTemporaryCopy(URL(fileURLWithPath: "/repos/demo/Sources/App.swift"))
    )
  }

  /// The name a copy carries is enough on its own, since a copy put outside
  /// the temporary directory is still one.
  @Test func aCopyNamedForItsSourceIsOneWhereverItWasPut() {
    let copy = URL(fileURLWithPath: "/somewhere/NSIRD_Mail_A1B2/Attachment.pdf")
    #expect(DraggedFilePaths.isTemporaryCopy(copy))
  }

  @Test func aFolderOfTheUsersOwnCalledTemporaryItemsIsNotTheDragsCopy() {
    let mine = URL(fileURLWithPath: "/Users/x/TemporaryItems/notes.md")
    #expect(!DraggedFilePaths.isTemporaryCopy(mine))
  }

  /// A drag with no path has files not yet written, as out of Photos or Mail; taking no paths as
  /// enough would refuse the drop after the pane had offered it.
  @Test func aDragOfferingNoPathAtAllIsOneToAskThePromiseFor() {
    #expect(DraggedFilePaths.needsPromise(for: []))
  }

  @Test func onlyADragCarryingACopyNeedsThePromiseAsked() {
    let mine = URL(fileURLWithPath: "/Users/x/Desktop/Notes.md")
    let copy = URL(fileURLWithPath: "/somewhere/NSIRD_screencaptureui_A1/Shot.png")

    #expect(!DraggedFilePaths.needsPromise(for: [mine]))
    #expect(DraggedFilePaths.needsPromise(for: [copy]))
    #expect(DraggedFilePaths.needsPromise(for: [mine, copy]))
  }

  /// The drop pastes the user's own files at once and asks for the copies again through the
  /// promise, so a drop that took only the promised ones would lose these.
  @Test func aDragOfBothKindsKeepsTheFilesTheUserHas() {
    let mine = URL(fileURLWithPath: "/Users/x/Desktop/Notes.md")
    let copy = URL(fileURLWithPath: "/somewhere/NSIRD_screencaptureui_A1/Shot.png")

    #expect(DraggedFilePaths.originals(among: [mine, copy]) == [mine])
    #expect(DraggedFilePaths.originals(among: [copy]).isEmpty)
    #expect(DraggedFilePaths.originals(among: [mine]) == [mine])
    #expect(DraggedFilePaths.originals(among: []).isEmpty)
  }
}

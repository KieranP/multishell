import AppKit
import MultishellAppCore
import Testing

@testable import MultishellAppUI

extension NewWorktreeBranchNameFieldTests {
  @Test func undoTakesBackAFixedPasteWholeInTheFieldAndTheDraft() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.paste("Admin::Users")
    #expect(try sheet.undoManager().canUndo)
    try sheet.undo()
    #expect(try sheet.field().stringValue == "")
    #expect(sheet.draft.branch == "")
  }

  @Test func redoBringsBackTheFixedNameInTheFieldAndTheDraft() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.type("Admin::Users")
    try sheet.undo()
    #expect(sheet.draft.branch == "")
    try sheet.redo()
    #expect(try sheet.field().stringValue == "Admin-Users")
    #expect(sheet.draft.branch == "Admin-Users")
  }

  @Test func eachUndoAfterKeystrokesLeavesTheFieldAndTheDraftAgreeing() throws {
    let sheet = BranchNameFieldHarness()
    for text in ["a", ":", "b", " ", "c"] { try sheet.type(text) }
    while try sheet.undoManager().canUndo {
      try sheet.undo()
      let shown = try sheet.field().stringValue
      #expect(sheet.draft.branch == shown, "\(shown.debugDescription)")
    }
    #expect(try sheet.field().stringValue == "")
  }

  @Test func undoOfPlainTypingReachesTheDraftToo() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.type("abc")
    try sheet.undo()
    #expect(try sheet.field().stringValue == "")
    #expect(sheet.draft.branch == "")
  }

  /// The field stops following its editor when editing ends, which is safe
  /// only while no undo outlives the editing it came from.
  @Test func leavingTheFieldEndsItsUndoHistory() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.type("a:b")
    #expect(try sheet.undoManager().canUndo)
    try sheet.pressTab()
    try sheet.refocusField()
    #expect(try sheet.undoManager().canUndo == false)
    #expect(try sheet.field().stringValue == "a-b")
    #expect(sheet.draft.branch == "a-b")
  }
}

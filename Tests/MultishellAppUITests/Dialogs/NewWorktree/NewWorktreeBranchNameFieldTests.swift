import AppKit
import MultishellAppCore
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct NewWorktreeBranchNameFieldTests {
  @Test func aTypedNameShowsFixedInTheFieldWhileItIsStillBeingEdited() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.type("Admin::UsersController#index")
    #expect(try sheet.field().stringValue == "Admin-UsersController-index")
    #expect(try sheet.editor().selectedRange().location == 27)
  }

  @Test func whatTheFieldShowsIsWhatTheDraftWillCreate() throws {
    let sheet = BranchNameFieldHarness()
    for text in ["feat", "/", "tabs", " ", "#", "x"] { try sheet.type(text) }
    #expect(try sheet.field().stringValue == "feat/tabs-x")
    #expect(sheet.draft.branch == "feat/tabs-x")
  }

  @Test func aCharacterTypedAfterADashFoldsIntoItAndTheCaretStaysAtTheEnd() throws {
    let sheet = BranchNameFieldHarness()
    for text in ["a", "-", ":", "b"] { try sheet.type(text) }
    #expect(try sheet.field().stringValue == "a-b")
    #expect(try sheet.editor().selectedRange().location == 3)
  }

  @Test func anEditInsideTheNameKeepsTheCaretBesideIt() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.type("ab")
    try sheet.placeCaret(at: 1)
    try sheet.type(" ")
    #expect(try sheet.field().stringValue == "a-b")
    #expect(try sheet.editor().selectedRange().location == 2)
  }

  @Test func aControllerActionPastedFromThePasteboardShowsFixed() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.paste("Admin::UsersController#index")
    #expect(try sheet.field().stringValue == "Admin-UsersController-index")
    #expect(sheet.draft.branch == "Admin-UsersController-index")
  }

  @Test func aPastedNameEndingInANewlineKeepsOnlyASpaceTheCreateTrims() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.paste("feature/foo\n")
    #expect(try sheet.field().stringValue == "feature/foo ")
  }

  @Test func theFixedNameIsBackInTheFieldAfterAVisitToTheExistingBranchPicker() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.paste("Admin::Users")
    sheet.changeDraft { draft in
      draft.createsBranch = false
      draft.fitBranchToMode(checkedOut: [])
    }
    sheet.changeDraft { draft in
      draft.createsBranch = true
      draft.fitBranchToMode(checkedOut: [])
    }
    #expect(try sheet.field().stringValue == "Admin-Users")
  }

  @Test func aDraftChangedOutsideTheFieldShowsInIt() throws {
    let sheet = BranchNameFieldHarness()
    sheet.changeDraft { $0.branch = "release" }
    #expect(try sheet.field().stringValue == "release")
  }
}

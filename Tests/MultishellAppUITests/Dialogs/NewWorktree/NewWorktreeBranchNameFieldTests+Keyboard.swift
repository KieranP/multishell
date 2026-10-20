import AppKit
import Testing

@testable import MultishellAppUI

extension NewWorktreeBranchNameFieldTests {
  @Test func returnInTheFieldPressesTheSheetsDefaultButton() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.type("feat")
    #expect(try sheet.pressReturn())
    #expect(sheet.defaultButtonPresses == 1)
  }

  @Test func tabInTheFieldMovesOnToTheNextField() throws {
    let sheet = BranchNameFieldHarness()
    try sheet.type("feat")
    try sheet.pressTab()
    let focused = try #require(sheet.focusedTextField)
    #expect(focused !== (try sheet.field()))
  }
}

import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite(.serialized) @MainActor
struct QuickSwitcherTextFieldTests {
  @Test func theFieldTakesTheKeyboardWithTheCaretAfterItsTextAndNothingSelected() throws {
    let harness = QuickSwitcherFieldHarness(text: "split")

    let editor = try harness.editor()

    #expect(editor.selectedRange() == NSRange(location: 5, length: 0))
  }

  @Test func theCaretWearsTheFieldsTextColourFromTheStart() throws {
    let harness = QuickSwitcherFieldHarness()

    let field = try harness.field()

    #expect(try harness.editor().insertionPointColor == field.textColor)
  }

  @Test func whatIsTypedReachesTheModel() throws {
    let harness = QuickSwitcherFieldHarness()

    try harness.type("down")

    #expect(harness.model.quickSwitcher?.text == "down")
    #expect(
      harness.model.quickSwitcherResults.selection == .command(path: ["Terminal", "Split Down"])
    )
  }

  @Test func aGreaterThanSignTypedFirstInAllLeavesTheFieldEmptyOnCommands() throws {
    let harness = QuickSwitcherFieldHarness(scope: .all)

    try harness.type(">")

    #expect(harness.model.quickSwitcher?.scope == .commands)
    #expect(try harness.field().stringValue == "")
  }

  @Test func aGreaterThanSignPastedWithTextLeavesTheCaretAfterTheRest() throws {
    let harness = QuickSwitcherFieldHarness(scope: .all)

    try harness.type(">split")

    #expect(try harness.field().stringValue == "split")
    #expect(try harness.editor().selectedRange() == NSRange(location: 5, length: 0))
  }

  @Test func aKeyTypedHardOnAGreaterThanSignLeavesNoGreaterThanSignBehind() throws {
    let harness = QuickSwitcherFieldHarness(scope: .all)

    try harness.typeWithoutARedrawBetween([">", "s"])

    #expect(harness.model.quickSwitcher?.scope == .commands)
    #expect(harness.model.quickSwitcher?.text == "s")
    #expect(try harness.field().stringValue == "s")
  }

  @Test func textTheModelSetsWhileTheFieldEditsIsShownWithoutClosingIt() throws {
    let harness = QuickSwitcherFieldHarness()
    _ = try harness.editor()

    harness.setTextInTheModel("split")

    #expect(harness.model.quickSwitcher?.text == "split")
    #expect(try harness.field().stringValue == "split")
    #expect(try harness.field().currentEditor() != nil)
  }

  @Test func downAndUpMoveTheSelectionAndLeaveTheText() throws {
    let harness = QuickSwitcherFieldHarness()

    try harness.press(#selector(NSResponder.moveDown(_:)))
    #expect(
      harness.model.quickSwitcherResults.selection == .command(path: ["Terminal", "Split Down"])
    )

    try harness.press(#selector(NSResponder.moveUp(_:)))
    #expect(
      harness.model.quickSwitcherResults.selection == .command(path: ["Terminal", "Split Right"])
    )
  }

  @Test func tabAndShiftTabStepTheScope() throws {
    let harness = QuickSwitcherFieldHarness(scope: .all)

    try harness.press(#selector(NSResponder.insertTab(_:)))
    #expect(harness.model.quickSwitcher?.scope == .agents)

    try harness.press(#selector(NSResponder.insertBacktab(_:)))
    #expect(harness.model.quickSwitcher?.scope == .all)
  }

  @Test func anotherFieldTakingTheKeyboardClosesIt() throws {
    let harness = QuickSwitcherFieldHarness()

    harness.giveTheKeyboardToAnotherField()

    #expect(harness.model.quickSwitcher == nil)
  }

  @Test(arguments: [
    #selector(NSResponder.deleteBackward(_:)),
    #selector(NSResponder.deleteWordBackward(_:)),
    #selector(NSResponder.deleteToBeginningOfLine(_:)),
  ])
  func anyBackspaceInTheEmptyFieldGoesBackToAll(command: Selector) throws {
    let harness = QuickSwitcherFieldHarness(scope: .commands)

    try harness.press(command)

    #expect(harness.model.quickSwitcher?.scope == .all)
  }

  @Test func undoDoesNotReplayAnotherFieldsTypingIntoIt() throws {
    let harness = QuickSwitcherFieldHarness()
    try harness.typeInTheOtherFieldThenComeBack("zzz")
    try harness.type("abc")

    try harness.undo()

    #expect(try harness.field().stringValue == "abc")
    #expect(harness.model.quickSwitcher?.text == "abc")
  }

  @Test func escapeClosesIt() throws {
    let harness = QuickSwitcherFieldHarness()

    try harness.press(#selector(NSResponder.cancelOperation(_:)))

    #expect(harness.model.quickSwitcher == nil)
  }

  @Test func returnChoosesTheSelectedRowAndClosesIt() throws {
    let harness = QuickSwitcherFieldHarness(scope: .worktrees)

    try harness.press(#selector(NSResponder.insertNewline(_:)))

    #expect(harness.model.workspace.selectedWorktreeID == harness.worktree.id)
    #expect(harness.model.quickSwitcher == nil)
  }
}

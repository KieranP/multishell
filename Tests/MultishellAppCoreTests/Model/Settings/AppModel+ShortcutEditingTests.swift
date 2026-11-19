import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelShortcutEditingTests {
  private let backslash = KeyCombination(.character("\\"), .command)
  private let commandK = KeyCombination(.character("k"), .command)

  @Test func recordedKeysAreSetOrTurnedIntoTheNextStep() {
    let harness = Harness()
    harness.model.startRecordingShortcut(for: .splitRight)

    harness.model.takeRecordedShortcut(backslash, for: .splitRight)
    #expect(harness.model.shortcutEditing == nil)
    #expect(harness.model.shortcutKeys(for: .splitRight) == backslash)

    harness.model.takeRecordedShortcut(ReservedShortcut.quit.combination, for: .splitDown)
    #expect(
      harness.model.shortcutEditing
        == ShortcutEditing(command: .splitDown, step: .recording(.reserved(.quit)))
    )

    harness.model.takeRecordedShortcut(backslash, for: .splitDown)
    #expect(
      harness.model.shortcutEditing
        == ShortcutEditing(
          command: .splitDown,
          step: .confirming(backslash, takenFrom: .splitRight),
        )
    )
  }

  @Test func onlyTheRowBeingEditedHasAStep() {
    let harness = Harness()
    harness.model.startRecordingShortcut(for: .splitRight)

    #expect(harness.model.shortcutEditingStep(for: .splitRight) == .recording(nil))
    #expect(harness.model.shortcutEditingStep(for: .splitDown) == nil)
  }

  @Test func replaceAnswersTheOpenQuestionLeavingTheHolderNone() {
    let harness = Harness()
    harness.model.takeRecordedShortcut(backslash, for: .splitRight)
    harness.model.takeRecordedShortcut(backslash, for: .splitDown)

    harness.model.replaceAskedShortcut()

    #expect(harness.model.shortcutEditing == nil)
    #expect(harness.model.shortcutKeys(for: .splitDown) == backslash)
    #expect(harness.model.shortcutKeys(for: .splitRight) == nil)
  }

  @Test func anOpenQuestionEndsWhenTheShortcutsChangeUnderIt() {
    let harness = Harness()
    harness.model.takeRecordedShortcut(backslash, for: .splitRight)
    harness.model.takeRecordedShortcut(backslash, for: .splitDown)

    harness.model.restoreDefaultShortcuts()

    #expect(harness.model.shortcutEditing == nil, "Replace would undo part of the restore")
    harness.model.replaceAskedShortcut()
    #expect(!harness.model.hasChangedShortcuts)
  }

  @Test func theRestoreQuestionEndsWhenTheShortcutsChangeOrThePageGoes() {
    let harness = Harness()
    harness.model.setShortcut(backslash, for: .splitRight)
    harness.model.askToRestoreShortcuts()
    #expect(harness.model.isAskingToRestoreShortcuts)

    harness.model.setShortcut(nil, for: .splitRight)
    #expect(!harness.model.isAskingToRestoreShortcuts)

    harness.model.askToRestoreShortcuts()
    harness.model.endShortcutsPageEdit()
    #expect(!harness.model.isAskingToRestoreShortcuts)
  }

  @Test func resetOntoADefaultAnotherCommandNowHoldsAsksFirst() {
    let harness = Harness()
    let splitDownKeys = ShortcutCommand.splitDown.defaultCombination
    harness.model.setShortcut(commandK, for: .splitDown)
    harness.model.setShortcut(splitDownKeys, for: .quickSwitcher)

    harness.model.resetShortcut(.splitDown)

    #expect(
      harness.model.shortcutEditing
        == ShortcutEditing(
          command: .splitDown,
          step: .confirming(splitDownKeys, takenFrom: .quickSwitcher),
        )
    )
    #expect(
      harness.model.shortcutKeys(for: .splitDown) == commandK,
      "nothing changes until Replace",
    )
  }

  @Test func resettingACommandToAFreeDefaultRemovesTheChangeWithoutAsking() {
    let harness = Harness()
    harness.model.setShortcut(backslash, for: .splitRight)

    harness.model.resetShortcut(.splitRight)

    #expect(harness.model.shortcutEditing == nil)
    #expect(!harness.model.isShortcutChanged(.splitRight))
  }

  @Test func deleteWhileRecordingLeavesTheCommandNoKeysAndEndsTheEdit() {
    let harness = Harness()
    harness.model.startRecordingShortcut(for: .closeFind)

    harness.model.clearRecordedShortcut(for: .closeFind)

    #expect(harness.model.shortcutEditing == nil)
    #expect(harness.model.shortcutKeys(for: .closeFind) == nil)
  }
}

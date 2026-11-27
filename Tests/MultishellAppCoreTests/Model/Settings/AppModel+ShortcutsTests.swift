import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelShortcutsTests {
  private let backslash = KeyCombination(.character("\\"), .command)

  @Test func anAllowedSetChangesTheKeysTheMenuAndTheEngine() {
    let harness = Harness()

    #expect(harness.model.setShortcut(backslash, for: .splitRight) == .allowed(nil))

    #expect(harness.model.shortcutKeys(for: .splitRight) == backslash)
    #expect(harness.platform.menuShortcuts[.splitRight] == .some(backslash))
    #expect(harness.engine.unbound.contains(backslash))
  }

  @Test func aRefusedOrTakenSetChangesNothing() {
    let harness = Harness()
    let quit = ReservedShortcut.quit.combination

    #expect(harness.model.setShortcut(quit, for: .splitRight) == .refused(.reserved(.quit)))
    #expect(
      harness.model.setShortcut(KeyCombination(.character("p"), .command), for: .splitRight)
        == .taken(holder: .quickSwitcher)
    )
    #expect(!harness.model.hasChangedShortcuts)
  }

  @Test func replaceLeavesTheCommandThatHeldTheKeysWithNone() {
    let harness = Harness()
    let switcherKeys = ShortcutCommand.quickSwitcher.defaultCombination

    harness.model.replaceShortcut(switcherKeys, for: .splitDown)

    #expect(harness.model.shortcutKeys(for: .splitDown) == switcherKeys)
    #expect(harness.model.shortcutKeys(for: .quickSwitcher) == nil)
    #expect(harness.platform.menuShortcuts[.quickSwitcher] == .some(nil))
  }

  @Test func restoreDefaultsClearsEveryChange() {
    let harness = Harness()
    harness.model.setShortcut(backslash, for: .splitRight)
    harness.model.setShortcut(nil, for: .closeFind)

    harness.model.restoreDefaultShortcuts()

    #expect(!harness.model.hasChangedShortcuts)
    #expect(
      harness.model.shortcutKeys(for: .closeFind) == ShortcutCommand.closeFind.defaultCombination
    )
  }

  @Test func theUnbindListHoldsTheDefaultAndTheOverrideButNoClipboardKeys() {
    let harness = Harness()
    harness.model.setShortcut(backslash, for: .splitRight)

    let unbinds = harness.model.surfaceUnbinds

    #expect(unbinds.contains(backslash))
    #expect(unbinds.contains(ShortcutCommand.splitRight.defaultCombination))
    for command in [ShortcutCommand.undo, .redo, .find] {
      #expect(unbinds.contains(command.defaultCombination), "fixed, yet a pane must give it up")
    }
    for command in ShortcutCommand.allCases where command.surfaceKeepsBinding {
      #expect(!unbinds.contains(command.defaultCombination), "\(command)")
    }
  }

  @Test func aCommandLeftAloneWhoseDefaultAnotherOverrideHoldsNamesThatCommand() {
    let harness = Harness()
    var overrides = ShortcutOverrides()
    overrides.set(.keys(ShortcutCommand.newTab.defaultCombination), for: .findNext)
    harness.store.setShortcutOverrides(overrides)

    #expect(harness.model.shortcutKeys(for: .newTab) == nil)
    #expect(harness.model.commandHoldingDefault(of: .newTab) == .findNext)
    #expect(
      harness.model.commandHoldingDefault(of: .findNext) == nil,
      "Find Next holds its own keys",
    )
  }

  @Test func aPartCountsItsChangedCommands() {
    let harness = Harness()
    harness.model.setShortcut(backslash, for: .splitRight)
    harness.model.setShortcut(nil, for: .nextTab)

    #expect(harness.model.changedShortcutCount(in: .shortcutsTerminal) == 2)
    #expect(harness.model.changedShortcutCount(in: .shortcutsFile) == 0)
  }

  @Test func aChangeWithoutCommandWarnsForAsLongAsItStands() {
    let harness = Harness()
    let controlR = KeyCombination(.character("r"), .control)
    harness.model.setShortcut(controlR, for: .quickSwitcher)

    #expect(
      harness.model.shortcutWarning(for: .quickSwitcher)
        == ShortcutWarning(keys: controlR, shellUse: .historySearch)
    )
    #expect(harness.model.shortcutWarning(for: .nextTab) == nil, "a default says nothing")
  }
}

import Testing

@testable import MultishellCore

@Suite
struct ShortcutOverridesTests {
  private let backslash = KeyCombination(.character("\\"), .command)

  @Test func aCommandLeftAloneHasItsDefault() {
    #expect(
      ShortcutOverrides().keys(for: .splitRight)
        == ShortcutCommand.splitRight.defaultCombination
    )
  }

  @Test func anOverrideOfNoKeysLeavesTheCommandNone() {
    var overrides = ShortcutOverrides()
    overrides.set(.noKeys, for: .closeFind)
    #expect(overrides.keys(for: .closeFind) == nil)
    #expect(overrides[.closeFind] == .noKeys)
  }

  @Test func settingACommandBackToItsDefaultRemovesTheOverride() {
    var overrides = ShortcutOverrides()
    overrides.set(.keys(backslash), for: .splitRight)
    overrides.set(.keys(ShortcutCommand.splitRight.defaultCombination), for: .splitRight)
    #expect(overrides.isEmpty)
  }

  @Test func aDefaultAnotherCommandsOverrideHoldsLeavesItsCommandNone() {
    var overrides = ShortcutOverrides()
    overrides.set(.keys(ShortcutCommand.splitDown.defaultCombination), for: .quickSwitcher)
    #expect(overrides.keys(for: .splitDown) == nil)
    #expect(
      overrides.command(holding: ShortcutCommand.splitDown.defaultCombination) == .quickSwitcher
    )
  }

  @Test func aFixedCommandKeepsItsKeys() {
    var overrides = ShortcutOverrides()
    overrides.set(.noKeys, for: .copy)
    #expect(overrides.isEmpty)
    #expect(overrides.keys(for: .copy) == ShortcutCommand.copy.defaultCombination)
  }
}

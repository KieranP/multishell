import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ShortcutOverridesJudgementTests {
  private let overrides = ShortcutOverrides()

  private func keys(_ character: Character, _ modifiers: ShortcutModifiers) -> KeyCombination {
    KeyCombination(.character(character), modifiers)
  }

  @Test func aKeyWithNoCommandControlOrOptionIsRefusedUnlessItIsAnFKey() {
    #expect(overrides.judge(keys("k", []), for: .findNext) == .refused(.needsModifier))
    #expect(overrides.judge(keys("k", .shift), for: .findNext) == .refused(.needsModifier))
    #expect(
      overrides.judge(KeyCombination(.function(5)), for: .findNext)
        == .allowed(ShortcutWarning(keys: KeyCombination(.function(5)), shellUse: nil))
    )
  }

  @Test func optionWithACharacterIsRefusedAsItTypesOneOnManyLayouts() {
    #expect(
      overrides.judge(keys("l", .option), for: .findNext) == .refused(.optionTypesCharacter)
    )
    #expect(
      overrides.judge(keys("l", [.option, .shift]), for: .findNext)
        == .refused(.optionTypesCharacter)
    )
    #expect(overrides.judge(keys("l", [.option, .command]), for: .findNext) == .allowed(nil))
  }

  @Test func optionWithAKeyThatEditsTextIsRefusedWithoutCommandOrControl() {
    for key in [ShortcutKey.backspace, .leftArrow, .rightArrow, .returnKey, .tab] {
      let combination = KeyCombination(key, .option)
      #expect(
        overrides.judge(combination, for: .findNext) == .refused(.optionEditsText),
        "\(key)",
      )
    }
    #expect(
      overrides.judge(KeyCombination(.space, .option), for: .findNext)
        == .refused(.optionTypesCharacter)
    )
    #expect(
      overrides.judge(KeyCombination(.backspace, [.option, .command]), for: .findNext)
        == .allowed(nil)
    )
  }

  @Test func controlShiftWithASidewaysArrowSelectsToALinesEndAndIsRefused() {
    for key in [ShortcutKey.leftArrow, .rightArrow] {
      let combination = KeyCombination(key, [.control, .shift])
      #expect(overrides.judge(combination, for: .findNext) == .refused(.editsText), "\(key)")
    }
  }

  @Test func commandWithAnArrowOrDeleteIsRefusedAsEveryTextFieldUsesIt() {
    for key in [ShortcutKey.leftArrow, .rightArrow, .upArrow, .downArrow, .backspace] {
      for modifiers in [ShortcutModifiers.command, [.command, .shift]] {
        let combination = KeyCombination(key, modifiers)
        #expect(overrides.judge(combination, for: .findNext) == .refused(.editsText), "\(key)")
      }
    }
    #expect(
      overrides.judge(KeyCombination(.rightArrow, [.command, .option]), for: .findNext)
        == .taken(holder: .focusNextGroup)
    )
  }

  @Test func optionWithAKeyTextFieldsDoNothingWithIsAllowedWithTheWarning() {
    for key in [ShortcutKey.home, .end] {
      let combination = KeyCombination(key, .option)
      #expect(
        overrides.judge(combination, for: .findNext)
          == .allowed(ShortcutWarning(keys: combination, shellUse: nil)),
        "\(key)",
      )
    }
    for key in [ShortcutKey.forwardDelete, .pageUp, .pageDown] {
      #expect(
        overrides.judge(KeyCombination(key, .option), for: .findNext) == .refused(.optionEditsText)
      )
    }
  }

  @Test func commandPeriodIsAppKitsCancelAndReserved() {
    #expect(overrides.judge(keys(".", .command), for: .findNext) == .refused(.reserved(.cancel)))
  }

  @Test func keysThePaneTypesBeforeTheMenusSeeThemAreRefused() {
    let controlReturn = KeyCombination(.returnKey, .control)
    let controlSlash = keys("/", .control)
    let commandControlReturn = KeyCombination(.returnKey, [.control, .command])
    #expect(overrides.judge(controlReturn, for: .findNext) == .refused(.programKey(controlReturn)))
    #expect(overrides.judge(controlSlash, for: .findNext) == .refused(.programKey(controlSlash)))
    #expect(
      overrides.judge(commandControlReturn, for: .findNext)
        == .refused(.programKey(commandControlReturn))
    )
    #expect(overrides.judge(keys("/", [.control, .command]), for: .findNext) == .allowed(nil))
  }

  @Test func appKitsOwnTabOverviewAndHelpSearchKeysAreReserved() {
    #expect(
      overrides.judge(keys("\\", [.shift, .command]), for: .findNext)
        == .refused(.reserved(.showAllTabs))
    )
    #expect(
      overrides.judge(keys("/", [.shift, .command]), for: .findNext)
        == .refused(.reserved(.helpSearch))
    )
  }

  @Test func theAppleMenusLogOutAndLockScreenKeysAreReserved() {
    #expect(
      overrides.judge(keys("q", [.shift, .command]), for: .findNext) == .refused(.reserved(.logOut))
    )
    #expect(
      overrides.judge(keys("q", [.option, .shift, .command]), for: .findNext)
        == .refused(.reserved(.logOutNow))
    )
    #expect(
      overrides.judge(keys("q", [.control, .command]), for: .findNext)
        == .refused(.reserved(.lockScreen))
    )
  }

  @Test func theSystemsScreenshotSpacesSearchAndInputSourceKeysAreReserved() {
    let systemKeys = [
      keys("3", [.shift, .command]), keys("4", [.shift, .command]), keys("5", [.shift, .command]),
      keys("3", [.control, .shift, .command]), keys("4", [.control, .shift, .command]),
      KeyCombination(.leftArrow, .control), KeyCombination(.rightArrow, .control),
      KeyCombination(.upArrow, .control), KeyCombination(.downArrow, .control),
      KeyCombination(.space, [.option, .command]), KeyCombination(.space, .control),
      KeyCombination(.space, [.control, .option]), KeyCombination(.space, [.control, .command]),
      KeyCombination(.tab, [.shift, .command]), keys("`", [.shift, .command]),
      KeyCombination(.function(5), .command), KeyCombination(.function(5), [.option, .command]),
      keys("d", [.control, .command]), keys("m", [.option, .command]),
    ]
    for combination in systemKeys {
      guard case .refused(.reserved) = overrides.judge(combination, for: .findNext) else {
        Issue.record("\(combination.glyphs) is the system's")
        continue
      }
    }
  }

  @Test func controlBracketIsAPanesEscapeAndRefused() {
    let controlBracket = keys("[", .control)
    #expect(
      overrides.judge(controlBracket, for: .findNext) == .refused(.programKey(controlBracket))
    )
  }

  @Test func everyReservedCombinationIsRefusedAsTheSystems() {
    for reserved in ReservedShortcut.allCases {
      #expect(
        overrides.judge(reserved.combination, for: .findNext) == .refused(.reserved(reserved))
      )
    }
  }

  @Test func theControlKeysAProgramNeedsAreRefused() {
    for character in ["c", "d", "z", "\\"] as [Character] {
      let combination = keys(character, .control)
      #expect(overrides.judge(combination, for: .findNext) == .refused(.programKey(combination)))
    }
  }

  @Test func keysWithoutCommandAreAllowedNamingWhatTheShellLoses() {
    #expect(
      overrides.judge(keys("r", .control), for: .findNext)
        == .allowed(ShortcutWarning(keys: keys("r", .control), shellUse: .historySearch))
    )
    #expect(
      overrides.judge(keys("g", [.control, .option]), for: .findNext)
        == .allowed(ShortcutWarning(keys: keys("g", [.control, .option]), shellUse: nil))
    )
  }

  @Test func anotherCommandsKeysAreTakenAndAFixedCommandsRefused() {
    #expect(
      overrides.judge(keys("p", .command), for: .findNext) == .taken(holder: .quickSwitcher)
    )
    #expect(overrides.judge(keys("c", .command), for: .findNext) == .refused(.heldByFixed(.copy)))
    #expect(overrides.judge(keys("f", .command), for: .findNext) == .refused(.heldByFixed(.find)))
    #expect(
      overrides.judge(keys("z", [.shift, .command]), for: .findNext)
        == .refused(.heldByFixed(.redo))
    )
  }

  @Test func aCommandsOwnKeysAreAllowed() {
    #expect(overrides.judge(keys("g", .command), for: .findNext) == .allowed(nil))
  }
}

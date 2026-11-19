import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ShortcutOverridesCodableTests {
  @Test func overridesAreWrittenAsCommandToKeysWithBlankForNone() throws {
    var overrides = ShortcutOverrides()
    overrides.set(.keys(KeyCombination(.character("\\"), .command)), for: .splitRight)
    overrides.set(.noKeys, for: .closeFind)
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(overrides))

    #expect(object as? [String: String] == ["split-right": "cmd+backslash", "close-find": ""])
  }

  @Test func blankAndWhitespaceReadAsNoKeys() throws {
    let overrides = try decodeJSON(
      ShortcutOverrides.self,
      #"{ "close-find": "", "find-next": " " }"#,
    )
    #expect(overrides[.closeFind] == .noKeys)
    #expect(overrides[.findNext] == .noKeys)
  }

  @Test func anUnknownCommandOrUnreadableKeysCostsThatEntryAlone() throws {
    let overrides = try decodeJSON(
      ShortcutOverrides.self,
      #"{ "warp-drive": "cmd+k", "split-right": "hyper+k", "split-down": 3, "find-next": "cmd+k" }"#,
    )
    #expect(overrides[.splitRight] == nil)
    #expect(overrides[.splitDown] == nil)
    #expect(overrides[.findNext] == .keys(KeyCombination(.character("k"), .command)))
  }

  @Test func aSecondOverrideOnKeysAnEarlierOneHoldsIsDropped() throws {
    let overrides = try decodeJSON(
      ShortcutOverrides.self,
      #"{ "split-down": "cmd+k", "new-tab": "cmd+k", "find-next": "cmd+c" }"#,
    )
    #expect(overrides[.newTab] == .keys(KeyCombination(.character("k"), .command)))
    #expect(overrides[.splitDown] == nil, "new-tab comes first among the commands")
    #expect(overrides[.findNext] == nil, "Copy holds ⌘C and cannot let it go")
  }

  @Test func keysTheSettingsPageWouldRefuseAreDroppedOnLoad() throws {
    let overrides = try decodeJSON(
      ShortcutOverrides.self,
      #"{ "split-right": "q", "split-down": "cmd+q", "find": "ctrl+c", "close-find": "alt+left" }"#,
    )
    #expect(overrides.isEmpty, "a hand edit must not bind a plain q or take ⌘Q")
  }

  @Test func spacesAroundAHandEditedSpellingAreIgnored() throws {
    let overrides = try decodeJSON(
      ShortcutOverrides.self,
      #"{ "split-right": " cmd+backslash " }"#,
    )
    #expect(overrides[.splitRight] == .keys(KeyCombination(.character("\\"), .command)))
  }

  @Test func aFixedCommandsOverrideIsDropped() throws {
    let overrides = try decodeJSON(
      ShortcutOverrides.self,
      #"{ "copy": "cmd+k", "undo": "cmd+u", "find": "cmd+j" }"#,
    )
    #expect(overrides.isEmpty)
  }

  @Test func aStateFileWithoutShortcutsOrWithABrokenValueKeepsTheDefaults() throws {
    #expect(try decodeJSON(Workspace.self, #"{ "projects": [] }"#).shortcutOverrides.isEmpty)
    #expect(
      try decodeJSON(Workspace.self, #"{ "projects": [], "shortcuts": [1] }"#).shortcutOverrides
        .isEmpty
    )
  }
}

import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlGlobalSettingTableTests {
  private func write(_ harness: Harness, _ key: String, _ value: String) async -> ControlReply? {
    await harness.messageSource.ask(.writeGlobalSetting(key: key, value: value))
  }

  @Test func eachChangeableCommandHasARowReadInTheStateFilesSpelling() async throws {
    let harness = Harness()

    let reply = try #require(await harness.messageSource.ask(.readGlobalSettings(key: nil)))

    #expect(reply.outputFields["shortcuts.split-right"] as? String == "cmd+d")
    #expect(reply.outputFields["shortcuts.copy"] == nil, "Copy cannot change")
  }

  @Test func aRowTakesTheStoredSpellingGlyphsOrNone() async {
    let harness = Harness()

    #expect(await write(harness, "shortcuts.split-right", "cmd+backslash") == .done)
    #expect(await write(harness, "shortcuts.split-down", "⌥⌘\\") == .done)
    #expect(await write(harness, "shortcuts.close-find", "none") == .done)

    #expect(
      harness.model.shortcutKeys(for: .splitRight) == KeyCombination(.character("\\"), .command)
    )
    #expect(
      harness.model.shortcutKeys(for: .splitDown)
        == KeyCombination(.character("\\"), [.command, .option])
    )
    #expect(harness.model.shortcutKeys(for: .closeFind) == nil)
  }

  @Test func aRowRefusesWhatTheJudgeRefusesOrAnotherCommandHolds() async {
    let harness = Harness()

    #expect(
      await write(harness, "shortcuts.split-right", "cmd+q")
        == .refused(.invalidValue(key: "shortcuts.split-right", value: "cmd+q"))
    )
    #expect(
      await write(harness, "shortcuts.split-right", "cmd+p")
        == .refused(.invalidValue(key: "shortcuts.split-right", value: "cmd+p"))
    )
    #expect(!harness.model.hasChangedShortcuts)
  }

  @Test func aCommandWhoseDefaultAnotherHoldsReadsBlankSoWritingItBackChangesNothing() async throws
  {
    let harness = Harness()
    var overrides = ShortcutOverrides()
    overrides.set(.keys(ShortcutCommand.newTab.defaultCombination), for: .findNext)
    harness.store.setShortcutOverrides(overrides)

    let reply = try #require(await harness.messageSource.ask(.readGlobalSettings(key: nil)))
    let read = try #require(reply.outputFields["shortcuts.new-tab"] as? String)
    #expect(read.isEmpty)
    #expect(await write(harness, "shortcuts.new-tab", read) == .done)
    #expect(!harness.model.isShortcutChanged(.newTab))
  }

  @Test func aBlankValueResetsTheCommand() async {
    let harness = Harness()
    harness.model.setShortcut(nil, for: .closeFind)

    #expect(await write(harness, "shortcuts.close-find", "") == .done)

    #expect(!harness.model.isShortcutChanged(.closeFind))
  }
}

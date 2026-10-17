import Foundation
import TestScratch
import Testing
import os

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelAppearanceTests {
  private static let mint = RGB(red: 0xa0, green: 0xf0, blue: 0xc0)

  private func saveDarkThemeWithMintTerminal(in harness: Harness) throws -> URL {
    try FileManager.default.createDirectory(at: harness.themes, withIntermediateDirectories: true)
    let file = harness.themes.appendingPathComponent("mine.json")
    try Data(
      ##"{ "id": "multishell.dark", "name": "Mine", "terminal": { "background": "#a0f0c0" } }"##
        .utf8
    ).write(to: file)
    return file
  }

  @Test func aThemeSavedInTheThemesFolderIsDrawnAndSentToTheTerminalsWithoutARestart() async throws
  {
    let harness = Harness()
    harness.model.setTheme(Theme.multishellDark.id)
    let file = try saveDarkThemeWithMintTerminal(in: harness)

    await harness.model.noteFileChanges([file.deletingLastPathComponent()])

    #expect(harness.model.currentTheme.terminalRGB(.background) == Self.mint)
    #expect(harness.engine.appliedThemes.last?.terminalRGB(.background) == Self.mint)
  }

  @Test func theReloadButtonSendsTheReloadedThemeToTheTerminals() async throws {
    let harness = Harness()
    harness.model.setTheme(Theme.multishellDark.id)
    _ = try saveDarkThemeWithMintTerminal(in: harness)

    await harness.model.reloadThemes()

    #expect(harness.engine.appliedThemes.last?.terminalRGB(.background) == Self.mint)
  }

  @Test func theThemesFolderIsMadeBeforeTheWatcherIsArmedOnIt() async throws {
    let harness = Harness()
    var foundAtArming: [Bool] = []
    harness.watcher.onWatch = { directories in
      guard directories.contains(harness.themes) else { return }
      foundAtArming.append(FileManager.default.fileExists(atPath: harness.themes.path))
    }

    await harness.model.rearmWatcher(evenIfUnchanged: true)

    #expect(foundAtArming == [true])
  }

  @Test func launchArmsTheWatcherOnTheThemesFolder() async {
    let harness = Harness()

    await harness.model.start()

    #expect(harness.watcher.watched.contains(harness.themes))
  }

  @Test func aBrokenThemeIsReportedOnceRatherThanOnEverySaveInTheFolder() async throws {
    let harness = Harness()
    let file = try saveDarkThemeWithMintTerminal(in: harness)
    try Data("{".utf8).write(to: harness.themes.appendingPathComponent("broken.json"))
    await harness.model.reloadThemes()
    #expect(harness.model.presentedError != nil)
    harness.model.presentedError = nil

    try Data(#"{ "id": "user.other", "name": "Other" }"#.utf8).write(to: file)
    await harness.model.noteFileChanges([harness.themes])

    #expect(harness.model.presentedError == nil)
  }

  @Test func aChangeOutsideTheThemesFolderReadsNoTheme() async throws {
    let harness = Harness()
    let applied = harness.engine.appliedThemes.count
    _ = try saveDarkThemeWithMintTerminal(in: harness)

    await harness.model.noteFileChanges([harness.root])

    #expect(harness.engine.appliedThemes.count == applied)
    #expect(harness.model.currentTheme.terminalRGB(.background) != Self.mint)
  }

  @Test func fixingOneOfTwoBrokenThemesRaisesNoAlertForTheOneStillBroken() async throws {
    let harness = Harness()
    try FileManager.default.createDirectory(at: harness.themes, withIntermediateDirectories: true)
    for name in ["a.json", "b.json"] {
      try Data("{".utf8).write(to: harness.themes.appendingPathComponent(name))
    }
    await harness.model.reloadThemes()
    harness.model.presentedError = nil

    try Data(#"{ "id": "user.b", "name": "B" }"#.utf8)
      .write(to: harness.themes.appendingPathComponent("b.json"))
    await harness.model.reloadThemes()

    #expect(harness.model.presentedError == nil)
  }

  @Test func aThemeBrokenBesideOneAlreadyBrokenIsTheOneTheAlertNames() async throws {
    let harness = Harness()
    try FileManager.default.createDirectory(at: harness.themes, withIntermediateDirectories: true)
    try Data("{".utf8).write(to: harness.themes.appendingPathComponent("a.json"))
    await harness.model.reloadThemes()

    try Data("{".utf8).write(to: harness.themes.appendingPathComponent("z.json"))
    await harness.model.reloadThemes()

    #expect(harness.model.presentedError?.message.hasPrefix("z.json") == true)
  }

  @Test func aReloadOvertakenByALaterOneDoesNotPutItsOlderReadBack() async throws {
    let harness = Harness()
    harness.model.setTheme(Theme.multishellDark.id)
    _ = try saveDarkThemeWithMintTerminal(in: harness)
    let reads = OSAllocatedUnfairLock(initialState: 0)
    let gate = DispatchSemaphore(value: 0)
    harness.model.loadThemeCatalogue = { directory in
      let read = reads.withLock { count in
        count += 1
        return count
      }
      guard read > 1 else {
        gate.wait()
        return .builtinsOnly
      }
      return ThemeCatalogue.loadRemovingStrayExamples(from: directory)
    }

    let older = Task { await harness.model.reloadThemes() }
    try await waitUntil { reads.withLock { $0 } == 1 }
    await harness.model.reloadThemes()
    gate.signal()
    await older.value

    #expect(harness.model.currentTheme.terminalRGB(.background) == Self.mint)
  }

  @Test func aBrokenThemeSavedAgainStillBrokenIsNotAlertedAgain() async throws {
    let harness = Harness()
    try FileManager.default.createDirectory(at: harness.themes, withIntermediateDirectories: true)
    let file = harness.themes.appendingPathComponent("mine.json")
    try Data(#"{ "id": "mine",, }"#.utf8).write(to: file)
    await harness.model.reloadThemes()
    harness.model.presentedError = nil

    try Data(#"{ "id": "mine", "name": "Mine",, }"#.utf8).write(to: file)
    await harness.model.reloadThemes()

    #expect(harness.model.presentedError == nil)
  }

  @Test func twoThemesBrokenInOneReadAreBothNamedInTheOneAlert() async throws {
    let harness = Harness()
    try FileManager.default.createDirectory(at: harness.themes, withIntermediateDirectories: true)
    for name in ["a.json", "b.json"] {
      try Data("{".utf8).write(to: harness.themes.appendingPathComponent(name))
    }

    await harness.model.reloadThemes()

    let message = try #require(harness.model.presentedError?.message)
    #expect(message.contains("a.json") && message.contains("b.json"))
  }
}

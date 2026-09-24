import Foundation
import GhosttyTerminal
import Testing

@testable import Multishell

/// libghostty refuses a config file whole over any one complaint, so a key it
/// cannot answer would otherwise cost the user every other key in the file.
@Suite
struct GhosttyUserConfigTests {
  @Test func withNoFileTheBaseIsTheAppsOwnDefaults() {
    #expect(GhosttyUserConfig.base(userContents: []) == GhosttyUserConfig.defaults.rendered)
  }

  @Test func theUsersFileComesAfterTheDefaultsSoAKeyInBothIsTheirs() throws {
    let rendered = GhosttyUserConfig.base(userContents: ["window-padding-x = 24"])
    let app = try #require(rendered.range(of: "window-padding-x = 8"))
    let user = try #require(rendered.range(of: "window-padding-x = 24"))
    #expect(app.lowerBound < user.lowerBound)
  }

  /// `fileURLs` is in the order Ghostty reads them, so the app-support file
  /// is the later word where a user keeps both.
  @Test func theAppSupportFileComesAfterTheXDGOne() throws {
    let rendered = GhosttyUserConfig.base(userContents: ["font-size = 9", "font-size = 11"])
    let first = try #require(rendered.range(of: "font-size = 9"))
    let second = try #require(rendered.range(of: "font-size = 11"))
    #expect(first.lowerBound < second.lowerBound)
  }

  @Test func bothFileNamesAreReadInBothPlacesInGhosttysOrder() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path + "/"
    #expect(
      GhosttyUserConfig.fileURLs.map { $0.path.replacingOccurrences(of: home, with: "") } == [
        ".config/ghostty/config",
        ".config/ghostty/config.ghostty",
        "Library/Application Support/com.mitchellh.ghostty/config",
        "Library/Application Support/com.mitchellh.ghostty/config.ghostty",
      ])
  }

  @Test func aFileWithWindowsLineEndingsIsReadLineByLine() {
    let contents = "font-size = 13\r\ncommand = /bin/dash\r\ncursor-style = bar\r\n"
    let rendered = GhosttyUserConfig.base(userContents: [contents])
    #expect(!rendered.contains("dash"))
    #expect(rendered.hasSuffix("font-size = 13\ncursor-style = bar"))
  }

  /// A comment does nothing in the config libghostty gets, and letting one
  /// through would let through every line that is not a key.
  @Test func onlySettingsReachLibghostty() {
    let contents = """
      # mine
      font-family = Berkeley Mono

      mouse-hide-while-typing = true
      """
    let rendered = GhosttyUserConfig.base(userContents: [contents])
    #expect(rendered.hasSuffix("font-family = Berkeley Mono\nmouse-hide-while-typing = true"))
    #expect(!rendered.contains("# mine"))
  }

  /// Keys that would override one of the app's own decisions are dropped. Ghostty
  /// renamed `scrollback-limit` to `scrollback-limit-bytes`, so both spellings land.
  @Test func onlyWhatASurfaceReadsIsLetThrough() {
    let contents = """
      theme = "Github Light Default"
      command = /opt/homebrew/bin/fish
        initial-command=tmux attach
      input = raw:echo hello
      working-directory = ~/elsewhere
      title = Ghostty
      shell-integration = none
      wait-after-command = true
      COMMAND = /bin/dash
      command-palette-entry = title:Foo,action:ignore
      auto-update-channel = tip
      macos-titlebar-style = tabs
      window-save-state = always
      env = ZDOTDIR=/somewhere/else
      not-a-key-any-ghostty-has = 1
      font-family = Cousine Nerd Font Mono
      font-shaping-break = cursor
      scrollback-limit = 52428800
      scrollback-limit-bytes = 52428800
      keybind = super+v=paste_from_clipboard
      macos-option-as-alt = left
      shell-integration-features = no-cursor
      title-report = true
      window-padding-balance = true
      """
    let rendered = GhosttyUserConfig.base(userContents: [contents])
    for gone in [
      "Github Light Default", "fish", "tmux", "echo hello", "elsewhere", "title = Ghostty",
      "shell-integration = none", "wait-after-command", "dash", "command-palette-entry",
      "auto-update-channel", "macos-titlebar-style", "window-save-state", "ZDOTDIR",
      "not-a-key-any-ghostty-has",
    ] {
      #expect(!rendered.contains(gone), "\(gone) should have been dropped")
    }
    for kept in [
      "font-family = Cousine Nerd Font Mono", "font-shaping-break = cursor",
      "scrollback-limit = 52428800", "scrollback-limit-bytes = 52428800",
      "keybind = super+v=paste_from_clipboard", "macos-option-as-alt = left",
      "shell-integration-features = no-cursor", "title-report = true",
      "window-padding-balance = true",
    ] {
      #expect(rendered.contains(kept), "\(kept) should have been kept")
    }
  }

  @Test func aFileIsReadWhereItIsAndAMissingOneCostsNothing() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("config", isDirectory: false)
    try "cursor-style = bar\n".write(to: file, atomically: true, encoding: .utf8)
    let absent = directory.appendingPathComponent("absent", isDirectory: false)

    #expect(
      GhosttyUserConfig.base(reading: [file, absent])
        == GhosttyUserConfig.base(userContents: ["cursor-style = bar\n"]))
    #expect(GhosttyUserConfig.base(reading: [absent]) == GhosttyUserConfig.defaults.rendered)
  }

  @Test func anIncludedFileIsReadAfterTheFileThatNamesItAndFromBesideIt() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let parts = directory.appendingPathComponent("parts", isDirectory: true)
    try FileManager.default.createDirectory(at: parts, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let config = directory.appendingPathComponent("config", isDirectory: false)
    try "config-file = parts/extra\nconfig-file = ?parts/absent\nfont-size = 13\n".write(
      to: config, atomically: true, encoding: .utf8)
    try "font-size = 21\nconfig-file = \"../config\"\n".write(
      to: parts.appendingPathComponent("extra"), atomically: true, encoding: .utf8)

    let rendered = GhosttyUserConfig.base(reading: [config])

    let own = try #require(rendered.range(of: "font-size = 13"))
    let included = try #require(rendered.range(of: "font-size = 21"))
    #expect(own.upperBound <= included.lowerBound)
    #expect(rendered.components(separatedBy: "font-size = 13").count == 2, "a cycle reads once")
    #expect(!rendered.contains("config-file"))
  }

  @Test func anIncludeInAFileWithWindowsLineEndingsIsFollowed() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let config = directory.appendingPathComponent("config", isDirectory: false)
    try "config-file = theme.conf\r\nfont-size = 13\r\n".write(
      to: config, atomically: true, encoding: .utf8)
    try "cursor-style = bar\r\n".write(
      to: directory.appendingPathComponent("theme.conf"), atomically: true, encoding: .utf8)

    let rendered = GhosttyUserConfig.base(reading: [config])

    #expect(rendered.contains("font-size = 13"))
    #expect(rendered.contains("cursor-style = bar"))
  }

  @MainActor
  @Test func aReloadTakesTheFileAsItNowReadsAndKeepsTheTheme() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("config", isDirectory: false)
    try "cursor-style = bar\n".write(to: file, atomically: true, encoding: .utf8)
    let first = GhosttyUserConfig.base(reading: [file])
    let controller = TerminalController(configSource: .generated(first))
    let theme = TerminalConfiguration { $0.withBackground("#123456") }
    _ = controller.setTheme(TerminalTheme(light: theme, dark: theme))

    try "cursor-style = block\n".write(to: file, atomically: true, encoding: .utf8)
    let second = GhosttyUserConfig.reload(controller, reading: [file], over: first)

    #expect(second != first)
    #expect(controller.renderedConfig.contains("cursor-style = block"))
    #expect(!controller.renderedConfig.contains("cursor-style = bar"))
    #expect(controller.renderedConfig.contains("123456"))
    #expect(GhosttyUserConfig.reload(controller, reading: [file], over: second) == second)
  }

  /// Judged by libghostty itself. A real config here was refused over its theme
  /// line alone.
  @MainActor
  @Test func aConfigShapedLikeARealOneIsOneLibghosttyAccepts() {
    let contents = """
      # Ghostty's own template, as a Mac writes it
      theme = "Github Light Default"
      font-family = "Cousine Nerd Font Mono"
      font-feature = -calt, -liga, -dlig
      font-size = 13
      keybind = super+v=paste_from_clipboard
      macos-titlebar-style = tabs
      scrollback-limit = 52428800
      unfocused-split-opacity = 0.5
      window-padding-balance = true
      config-file = themes/one-that-is-not-there
      """
    let accepted = TerminalController(
      configSource: .generated(GhosttyUserConfig.base(userContents: [contents])))
    #expect(accepted.lastConfigurationIssue == nil)

    let refused = TerminalController(configSource: .generated(contents))
    #expect(refused.lastConfigurationIssue != nil)
  }

  /// Two shapes get past the key list: a family member the pinned build lacks, and a
  /// value it does not take on a key it has.
  @MainActor
  @Test func aLineLibghosttyRefusesIsDroppedAndTheRestOfTheFileStands() {
    let base = GhosttyUserConfig.base(userContents: [
      """
      font-not-a-real-key = 3
      copy-on-select = sideways
      cursor-style = bar
      """
    ])
    let controller = TerminalController(configSource: .generated(base))
    #expect(controller.lastConfigurationIssue != nil)

    GhosttyUserConfig.repair(controller, base: base)

    #expect(controller.lastConfigurationIssue == nil)
    #expect(controller.renderedConfig.contains("cursor-style = bar"))
    #expect(!controller.renderedConfig.contains("font-not-a-real-key"))
    #expect(!controller.renderedConfig.contains("copy-on-select"))
  }

  /// `repair` cannot place a complaint that names no line. Only a theme does that
  /// today, and a theme is dropped earlier, so this guards whatever does it next.
  @MainActor
  @Test func aComplaintThatNamesNoLineFallsBackToTheAppsDefaults() {
    let base = GhosttyUserConfig.defaults.rendered + "\ntheme = no-such-theme"
    let controller = TerminalController(configSource: .generated(base))
    #expect(controller.lastConfigurationIssue != nil)

    GhosttyUserConfig.repair(controller, base: base)

    #expect(controller.lastConfigurationIssue == nil)
    // `renderedConfig` is the effective one, the controller's own default
    // theme included, so the app's defaults are its opening lines.
    #expect(controller.renderedConfig.hasPrefix(GhosttyUserConfig.defaults.rendered))
    #expect(!controller.renderedConfig.contains("no-such-theme"))
  }
}

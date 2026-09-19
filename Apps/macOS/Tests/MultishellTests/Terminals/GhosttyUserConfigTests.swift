import Foundation
import GhosttyTerminal
import Testing

@testable import Multishell

/// The three layers a Ghostty surface is configured from. What this pins is
/// the order, the app's defaults being a floor the user's files may raise,
/// and the keys that are not theirs to set here. The last two tests are the
/// ones that matter: libghostty refuses a config file whole over any single
/// complaint, so a key it cannot answer would otherwise cost the user every
/// other key in the file.
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
    #expect(GhosttyUserConfig.fileURLs[0].path.hasSuffix(".config/ghostty/config"))
    #expect(
      GhosttyUserConfig.fileURLs[1].path
        .hasSuffix("Library/Application Support/com.mitchellh.ghostty/config"))
  }

  /// Settings and nothing else: a comment does no work in the config
  /// libghostty is handed, and letting one through would mean letting
  /// through every line that is not a key.
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

  /// A key has to be named, or start with a family that is, to reach
  /// libghostty. What this pins is the two halves of that: the keys that
  /// would take one of the app's own decisions away go nowhere, and both
  /// spellings of a key Ghostty has renamed still land, `scrollback-limit`
  /// having become `scrollback-limit-bytes` between versions.
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

  /// Against libghostty itself, which is the only judge of this. The theme
  /// line is what a real config here was refused over, every other key in it
  /// being fine.
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

  /// A line this libghostty cannot answer costs that line and nothing else.
  /// These are the two shapes that reaches it in, both of them past the
  /// list above: a member of an allowed family that the pinned build has
  /// not got, and a value a newer Ghostty added to a key it has
  /// (`copy-on-select = none` is real, and this build takes only false, true
  /// and clipboard).
  @MainActor
  @Test func aLineLibghosttyRefusesIsDroppedAndTheRestOfTheFileStands() {
    let base = GhosttyUserConfig.base(userContents: [
      """
      font-not-a-real-key = 3
      copy-on-select = none
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

  /// A complaint that names no line is the one `repair` cannot place, so the
  /// app's defaults are what is left. Nothing but a theme does that today,
  /// and a theme is dropped before it gets here, so this is the guard for
  /// whatever does it next.
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

import Foundation
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyUserConfigTests {
  @Test func withNoFileTheBaseIsTheAppsOwnDefaults() {
    #expect(GhosttyUserConfig.base(userContents: []) == GhosttyUserConfig.defaults.rendered)
  }

  @Test func aMiddleClickPastesTheClipboardUnlessTheUsersFileSaysOtherwise() throws {
    let rendered = GhosttyUserConfig.base(userContents: ["middle-click-action = primary-paste"])
    let app = try #require(rendered.range(of: "middle-click-action = clipboard-paste"))
    let user = try #require(rendered.range(of: "middle-click-action = primary-paste"))
    #expect(app.lowerBound < user.lowerBound, "the user's line comes later and wins")
  }

  @Test func aUserCanTurnOffSecureInputAtPasswordPrompts() throws {
    let rendered = GhosttyUserConfig.base(userContents: ["macos-auto-secure-input = false"])
    let loaded = try #require(GhosttyLoadedConfig.load(rendered))
    #expect(loaded.flag("macos-auto-secure-input") == false)
  }

  @Test func theAppsDefaultsAreAConfigLibghosttyAccepts() throws {
    let diagnostics = try libghosttyDiagnostics(GhosttyUserConfig.defaults.rendered)
    #expect(diagnostics.isEmpty, "\(diagnostics)")
  }

  /// The build leaves custom shaders out, so such a line would do nothing.
  @Test func aCustomShaderIsNotPassedOnToABuildWithoutThem() {
    let rendered = GhosttyUserConfig.base(userContents: [
      "custom-shader = ~/crt.glsl\ncustom-shader-animation = always"
    ])
    #expect(!rendered.contains("custom-shader"))
  }

  @Test func theUsersFileComesAfterTheDefaultsSoAKeyInBothIsTheirs() throws {
    let rendered = GhosttyUserConfig.base(userContents: ["window-padding-x = 24"])
    let app = try #require(rendered.range(of: "window-padding-x = 8"))
    let user = try #require(rendered.range(of: "window-padding-x = 24"))
    #expect(app.lowerBound < user.lowerBound)
  }

  /// `fileURLs` is in Ghostty's order, so a later file's key wins only if
  /// the rendering keeps the order the files were read in.
  @Test func theUsersFilesAreRenderedInTheOrderTheyWereRead() throws {
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
    let directory = try ScratchDirectory.make("ghostty-config")
    defer { ScratchDirectory.remove(directory) }
    let file = directory.appendingPathComponent("config", isDirectory: false)
    try "cursor-style = bar\n".write(to: file, atomically: true, encoding: .utf8)
    let absent = directory.appendingPathComponent("absent", isDirectory: false)

    #expect(
      GhosttyUserConfig.base(reading: [file, absent])
        == GhosttyUserConfig.base(userContents: ["cursor-style = bar\n"]))
    #expect(GhosttyUserConfig.base(reading: [absent]) == GhosttyUserConfig.defaults.rendered)
  }

  @Test func anIncludedFileIsReadAfterTheFileThatNamesItAndFromBesideIt() throws {
    let directory = ScratchDirectory.path("ghostty-config")
    let parts = directory.appendingPathComponent("parts", isDirectory: true)
    try FileManager.default.createDirectory(at: parts, withIntermediateDirectories: true)
    defer { ScratchDirectory.remove(directory) }
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
    let directory = try ScratchDirectory.make("ghostty-config")
    defer { ScratchDirectory.remove(directory) }
    let config = directory.appendingPathComponent("config", isDirectory: false)
    try "config-file = theme.conf\r\nfont-size = 13\r\n".write(
      to: config, atomically: true, encoding: .utf8)
    try "cursor-style = bar\r\n".write(
      to: directory.appendingPathComponent("theme.conf"), atomically: true, encoding: .utf8)

    let rendered = GhosttyUserConfig.base(reading: [config])

    #expect(rendered.contains("font-size = 13"))
    #expect(rendered.contains("cursor-style = bar"))
  }

  /// Judged by libghostty itself: a real config here drew a complaint over its
  /// theme line alone.
  @Test func aConfigShapedLikeARealOneIsOneLibghosttyAccepts() throws {
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
    let accepted = try libghosttyDiagnostics(GhosttyUserConfig.base(userContents: [contents]))
    #expect(accepted.isEmpty, "\(accepted)")
    #expect(try !libghosttyDiagnostics(contents).isEmpty)
  }
}

import Foundation

/// The user's own Ghostty configuration, the base a surface is configured
/// from, read as the first terminal opens and when the app comes to the front.
enum GhosttyUserConfig {
  /// Both names in both places Ghostty reads on a Mac, in its own order
  /// (`loadDefaultFiles`). `XDG_CONFIG_HOME` is not read.
  static let fileURLs: [URL] = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let directories = [".config/ghostty", "Library/Application Support/com.mitchellh.ghostty"]
    return directories.flatMap { directory in
      ["config", "config.ghostty"].map {
        home.appendingPathComponent("\(directory)/\($0)", isDirectory: false)
      }
    }
  }()

  /// What this app asks for before the user's files, so a key in both is the
  /// user's. Colours, font and unbound shortcuts are rendered after and win.
  static let defaults = GhosttyConfigText { config in
    config.set("cursor-style", "block")
    config.set("cursor-style-blink", "true")
    config.set("font-thicken", "true")
    config.set("window-padding-x", "8")
    config.set("window-padding-y", "6")
    // Ghostty's default pastes a selection clipboard, which the Mac has none of.
    config.set("middle-click-action", "clipboard-paste")
  }

  static func base(reading urls: [URL] = fileURLs) -> String {
    base(
      userContents: GhosttyConfigIncludes.contents(
        following: urls, home: FileManager.default.homeDirectoryForCurrentUser))
  }

  static func base(userContents: [String]) -> String {
    let userSettings = userContents.map(GhosttyConfigAllowList.settings(in:))
    return ([defaults.rendered] + userSettings).joined(separator: "\n")
  }
}

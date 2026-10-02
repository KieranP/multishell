import Foundation
import GhosttyTerminal

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
  static let defaults = TerminalConfiguration(startingFrom: .default) { builder in
    builder.withWindowPaddingX(8)
    builder.withWindowPaddingY(6)
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

  /// The files as they now read, where they changed since `previous`; the
  /// wrapper lays the theme and overrides back over the new base.
  @MainActor
  static func reload(
    _ controller: TerminalController, reading urls: [URL] = fileURLs, over previous: String
  ) -> String {
    let base = base(reading: urls)
    guard base != previous else { return previous }
    controller.updateConfigSource(.generated(base))
    GhosttyConfigRepair.repair(controller, base: base)
    return base
  }
}

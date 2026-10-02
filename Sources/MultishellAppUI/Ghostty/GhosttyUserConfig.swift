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
    repair(controller, base: base)
    return base
  }

  private static let repairPasses = 3

  /// libghostty refuses a file whole over one complaint, where Ghostty names
  /// the line and carries on. Blank the named lines and offer the rest again.
  @MainActor
  static func repair(_ controller: TerminalController, base: String) {
    var lines = base.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    for _ in 0..<repairPasses {
      guard let issue = controller.lastConfigurationIssue else { return }
      let refused = refusedLines(in: issue).filter { $0 >= 1 && $0 <= lines.count }
      guard !refused.isEmpty else { break }
      // Blanked rather than removed, so the next pass's line numbers are
      // this pass's.
      for number in refused { lines[number - 1] = "" }
      controller.updateConfigSource(.generated(lines.joined(separator: "\n")))
    }
    guard controller.lastConfigurationIssue != nil else { return }
    controller.updateConfigSource(.generated(defaults.rendered))
  }

  /// Diagnostics arrive as one `" | "`-joined string. Only that text says
  /// which line, so a reworded wrapper costs the repair, not the terminal.
  private static func refusedLines(in issue: String) -> [Int] {
    issue.components(separatedBy: " | ").compactMap { part in
      guard let range = part.range(of: #"\.conf:\d+:"#, options: .regularExpression) else {
        return nil
      }
      return Int(part[range].dropFirst(6).dropLast())
    }
  }
}

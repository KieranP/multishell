import Foundation
import GhosttyTerminal

/// The user's own Ghostty configuration, read as text and handed over as the
/// base a surface is configured from. Read once, at host creation.
enum GhosttyUserConfig {
  /// Both places Ghostty reads on a Mac, in its own order, measured with
  /// `ghostty +show-config`. `XDG_CONFIG_HOME` is not read.
  static let fileURLs: [URL] = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return [
      home.appendingPathComponent(".config/ghostty/config", isDirectory: false),
      home.appendingPathComponent(
        "Library/Application Support/com.mitchellh.ghostty/config", isDirectory: false),
    ]
  }()

  /// What this app asks for before the user's files, so a key in both is the
  /// user's. Colours, font and unbound shortcuts are rendered after and win.
  static let defaults = TerminalConfiguration(startingFrom: .default) { builder in
    builder.withWindowPaddingX(8)
    builder.withWindowPaddingY(6)
  }

  static func base(reading urls: [URL] = fileURLs) -> String {
    base(userContents: urls.compactMap { try? String(contentsOf: $0, encoding: .utf8) })
  }

  static func base(userContents: [String]) -> String {
    ([defaults.rendered] + userContents.map(usable)).joined(separator: "\n")
  }

  /// What a user's file may set; everything else is dropped. An allow list,
  /// a deny list having to grow with Ghostty; see terminals.md.
  private static let allowedPrefixes = [
    "adjust-", "background", "bell-", "clipboard-", "cursor-", "font-", "link",
    "mouse-", "palette", "resize-overlay", "scrollback-", "search-", "selection-",
    "window-padding-",
  ]

  /// The rest, one at a time. `env` is left off deliberately: a file setting
  /// one of the variables naming a session would break its reports.
  private static let allowedKeys: Set<String> = [
    "abnormal-command-exit-runtime", "alpha-blending", "bold-color", "click-repeat-interval",
    "copy-on-select", "custom-shader", "custom-shader-animation", "enquiry-response",
    "faint-opacity", "focus-follows-mouse", "foreground", "freetype-load-flags",
    "grapheme-width-method", "image-storage-limit", "key-remap", "keybind", "language",
    "macos-option-as-alt", "middle-click-action", "minimum-contrast", "osc-color-report-format",
    "progress-style", "right-click-action", "scroll-to-bottom", "scrollbar",
    "shell-integration-features", "term", "title-report", "vt-kam-allowed", "window-colorspace",
    "window-vsync",
  ]

  /// libghostty refuses a file whole over one complaint, where Ghostty names
  /// the line and carries on. Blank the named lines and offer the rest again.
  @MainActor
  static func repair(_ controller: TerminalController, base: String, passes: Int = 3) {
    var lines = base.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    for _ in 0..<passes {
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

  private static func usable(_ contents: String) -> String {
    contents
      .split(separator: "\n", omittingEmptySubsequences: false)
      .filter { isAllowed(key(of: $0)) }
      .joined(separator: "\n")
  }

  /// A line with no `=` has no key, so comments and blank lines go too: what
  /// libghostty is handed is then the settings and nothing else.
  private static func isAllowed(_ key: String) -> Bool {
    allowedKeys.contains(key) || allowedPrefixes.contains { key.hasPrefix($0) }
  }

  private static func key(of line: Substring) -> String {
    guard let separator = line.firstIndex(of: "=") else { return "" }
    return line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
  }
}

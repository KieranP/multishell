import Foundation
import GhosttyTerminal

/// The user's own Ghostty configuration, as the base a surface is configured
/// from.
///
/// libghostty loads no config of its own here, so the files are read and
/// handed over as text. They are read once, when the engine's host is
/// created, so an edit reaches terminals at the next launch.
enum GhosttyUserConfig {
  /// Both places Ghostty reads on a Mac, in the order it reads them: the XDG
  /// path first, the app-support file second, so the app-support file has the
  /// later word where a user keeps both. Measured rather than assumed, a key
  /// set in each and `ghostty +show-config` asked which survived.
  /// `XDG_CONFIG_HOME` is not read: an app launched from Finder is not given
  /// it, so honouring it would make a terminal's config depend on how the app
  /// was started.
  static let fileURLs: [URL] = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return [
      home.appendingPathComponent(".config/ghostty/config", isDirectory: false),
      home.appendingPathComponent(
        "Library/Application Support/com.mitchellh.ghostty/config", isDirectory: false),
    ]
  }()

  /// What this app asks for before the user's files are read, so a key in
  /// both is the user's. Colours, font and the unbound shortcuts are rendered
  /// after them instead and win; see `GhosttyTerminalHost`.
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

  /// What a user's file may set: everything else in it, comments included,
  /// is dropped before libghostty sees it.
  ///
  /// A list of what to refuse would have to grow with Ghostty, and the keys
  /// worth refusing are the ones a new release is likeliest to add to, being
  /// the ones about what runs and what a window is. `command`,
  /// `initial-command` and `input` reach the child, the first two in place of
  /// the session's shell and the third typed into it. `working-directory` is
  /// the worktree, `title` is the name the tab reads from escape sequences,
  /// `shell-integration` is the prompt marks that click-to-move and a
  /// command's exit code come from, and `wait-after-command` holds a surface
  /// open after its shell has gone. None of those is on this list, and nor is
  /// whatever is added beside them next.
  ///
  /// `theme` is left off for its own reason: it names a file in a themes
  /// directory this embedding does not ship, so it is the one complaint
  /// carrying no line number for `repair` to place, and the whole file would
  /// go with it. Nothing is lost, the app painting its own theme here.
  ///
  /// Prefixes where the whole family is about drawing or driving a surface.
  /// A family is also what carries a rename across a version: Ghostty split
  /// `scrollback-limit` into `scrollback-limit-bytes` and `-lines`, and
  /// `scrollback-` keeps every spelling of it whichever build is pinned.
  /// A member this libghostty has not got is `repair`'s to drop.
  private static let allowedPrefixes = [
    "adjust-", "background", "bell-", "clipboard-", "cursor-", "font-", "link",
    "mouse-", "palette", "resize-overlay", "scrollback-", "search-", "selection-",
    "window-padding-",
  ]

  /// The rest, one at a time. `macos-option-as-alt` is the only `macos-` key
  /// a surface reads; the others are a window's or the app's, as every
  /// `gtk-`, `quick-terminal-` and `window-` key but padding is. `env` is
  /// left off deliberately: the app gives each child the variables that name
  /// its session, and a file that set one of those would break the reports a
  /// tab's state is read from.
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

  /// libghostty refuses a config file whole over any one complaint, where
  /// Ghostty itself names the line, skips it and carries on. Do what Ghostty
  /// does: blank the lines it named and offer the rest again. A complaint
  /// naming no line, or a file still refused after a few passes, falls back
  /// to the app's defaults, which is what libghostty would have fallen back
  /// to on its own.
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

  /// Diagnostics arrive as one string, each `<path>:<line>:<key>: <message>`
  /// and joined by `" | "`. Only that text says which line, so a wrapper that
  /// words them differently costs the repair rather than the terminal: no
  /// line named is the fallback above.
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

/// The settings a user's Ghostty file may carry into a pane.
enum GhosttyConfigAllowList {
  /// What a user's file may set; everything else is dropped. An allow list,
  /// a deny list having to grow with Ghostty; see terminals.md.
  private static let prefixes = [
    "adjust-", "background", "bell-", "clipboard-", "cursor-", "font-", "link",
    "mouse-", "palette", "resize-overlay", "scrollback-", "search-", "selection-",
    "window-padding-",
  ]

  /// The rest, one at a time. `env` is left off deliberately: a file setting
  /// one of the variables naming a session would break its reports.
  private static let keys: Set<String> = [
    "abnormal-command-exit-runtime", "alpha-blending", "bold-color", "click-repeat-interval",
    "copy-on-select", "custom-shader", "custom-shader-animation", "enquiry-response",
    "faint-opacity", "focus-follows-mouse", "foreground", "freetype-load-flags",
    "grapheme-width-method", "image-storage-limit", "key-remap", "keybind", "language",
    "macos-option-as-alt", "middle-click-action", "minimum-contrast", "osc-color-report-format",
    "progress-style", "right-click-action", "scroll-to-bottom", "scrollbar",
    "shell-integration-features", "term", "title-report", "vt-kam-allowed", "window-colorspace",
    "window-vsync",
  ]

  /// The lines of a user's file this app passes on.
  static func settings(in contents: String) -> String {
    GhosttyConfigIncludes.lines(of: contents)
      .filter { isAllowed(GhosttyConfigIncludes.key(of: $0)) }
      .joined(separator: "\n")
  }

  /// A line with no `=` has no key, so comments and blank lines go too: what
  /// libghostty is handed is then the settings and nothing else.
  private static func isAllowed(_ key: String) -> Bool {
    keys.contains(key) || prefixes.contains { key.hasPrefix($0) }
  }
}

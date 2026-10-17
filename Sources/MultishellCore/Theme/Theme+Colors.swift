/// Every colour the app draws: the theme's own where it sets one that parses,
/// else its base theme's, so a user theme need only write what it changes.
extension Theme {
  /// Anything less would be a pane nobody can read, which looks broken
  /// rather than unfocused.
  static let minimumInactivePaneOpacity = 0.25

  /// A key no theme sets: one its section does not list, or a slot past the
  /// sixteenth. The base themes set every listed key: ThemeBuiltinsTests.
  private static let missing = RGB(red: 128, green: 128, blue: 128)

  /// Multishell Dark or Light, whichever matches `isDark`.
  private var base: Theme { isDark ? .multishellDark : .multishellLight }

  /// What every pane but the focused one draws at, faded towards the
  /// terminal's background, clamped before a pane looks broken.
  public var inactivePaneOpacity: Double {
    let opacity =
      [ownInactivePaneOpacity, base.ownInactivePaneOpacity].lazy
      .compactMap(\.self).first(where: \.isFinite) ?? 1
    return opacity.clamped(to: Self.minimumInactivePaneOpacity...1)
  }

  /// `nil` for a key set to `""`, which only the keys that take none allow.
  public func terminalRGB(_ key: TerminalColorKey) -> RGB? {
    for text in [terminalColors[key], base.terminalColors[key]].compactMap(\.self) {
      if key.takesNone, text.trimmedOrNil == nil { return nil }
      if let rgb = HexColor.parse(text) { return rgb }
    }
    return Self.missing
  }

  public func ansiRGB(_ slot: Int) -> RGB {
    resolved(ansiColors[slot], base.ansiColors[slot])
  }

  public func fileRGB(_ key: FileColorKey) -> RGB {
    resolved(fileColors[key], base.fileColors[key])
  }

  public func interfaceRGB(_ key: InterfaceColorKey, in section: InterfaceSection) -> RGB {
    resolved(interfaceColors[section]?[key], base.interfaceColors[section]?[key])
  }

  public func projectIconRGB(_ slot: Int) -> RGB {
    resolved(projectIconColors[slot], base.projectIconColors[slot])
  }

  /// `nil` draws the mark in the text around it, as an agent with no colour of its own.
  public func agentMarkRGB(_ agentID: String) -> RGB? {
    for text in [agentMarkColors[agentID], base.agentMarkColors[agentID]].compactMap(\.self) {
      if text.trimmedOrNil == nil { return nil }
      if let rgb = HexColor.parse(text) { return rgb }
    }
    return nil
  }

  private func resolved(_ own: String?, _ fallback: String?) -> RGB {
    own.flatMap(HexColor.parse) ?? fallback.flatMap(HexColor.parse) ?? Self.missing
  }
}

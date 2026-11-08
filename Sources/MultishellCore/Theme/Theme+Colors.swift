/// Every colour the app draws: the theme's own where it sets one that parses,
/// else its base theme's, so a user theme need only write what it changes.
extension Theme {
  /// A key no theme sets: one its section does not list, or a slot past the
  /// sixteenth. The base themes set every listed key: ThemeBuiltinsTests.
  private static let missing = RGB(red: 128, green: 128, blue: 128)

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

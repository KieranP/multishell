import MultishellCore

extension AppModel {
  public var currentTheme: Theme {
    workspace.appearance.theme(from: themes)
  }

  /// The font picker's row for the family in force, system monospace for none.
  public var terminalFontPickerID: String {
    workspace.appearance.terminalFontName ?? FontDetection.systemID
  }

  /// The UI font picker's row, the system font for none.
  public var uiFontPickerID: String {
    workspace.appearance.uiFontName ?? FontDetection.systemID
  }

  /// The file font picker's row, system monospace for none.
  public var fileFontPickerID: String {
    workspace.appearance.fileFontName ?? FontDetection.systemID
  }

  public func setTheme(_ id: Theme.ID) {
    store.setTheme(id)
    host.apply(currentTheme, appearance: workspace.appearance)
  }

  func setTerminalFont(name: String?, size: Double) {
    store.setTerminalFont(name: name, size: size)
    host.apply(currentTheme, appearance: workspace.appearance)
  }

  /// Takes a font picker's row id, keeping the size; the divider is no choice.
  public func setTerminalFontPickerID(_ id: String) {
    guard id != DetectionOption.dividerID else { return }
    setTerminalFont(
      name: id == FontDetection.systemID ? nil : id,
      size: workspace.appearance.terminalFontSize,
    )
  }

  /// Takes the terminal size slider's value, keeping the family.
  public func setTerminalFontSize(_ size: Double) {
    setTerminalFont(
      name: workspace.appearance.terminalFontName,
      size: size.clamped(to: Appearance.terminalFontSizes),
    )
  }

  func setFileFont(name: String?, size: Double) {
    store.setFileFont(name: name, size: size)
  }

  public func setFileFontPickerID(_ id: String) {
    guard id != DetectionOption.dividerID else { return }
    setFileFont(
      name: id == FontDetection.systemID ? nil : id,
      size: workspace.appearance.fileFontSize,
    )
  }

  public func setFileFontSize(_ size: Double) {
    setFileFont(
      name: workspace.appearance.fileFontName,
      size: size.clamped(to: Appearance.fileFontSizes),
    )
  }

  public func setUIFontPickerID(_ id: String) {
    guard id != DetectionOption.dividerID else { return }
    setUIFontName(id == FontDetection.systemID ? nil : id)
  }

  func setUIFontName(_ name: String?) {
    store.setUIFontName(name)
  }

  public func setUIFontSize(_ size: Double) {
    store.setUIFontSize(size.clamped(to: Appearance.uiFontSizes))
  }

  public func reloadThemes() {
    let catalogue = ThemeCatalogue.loadMovingStrayExamples()
    themes = catalogue.themes
    if let problem = catalogue.problems.first {
      presentedError = .themeUnreadable(problem)
    }
  }

  public func revealThemesFolder() {
    presentingFailure { try ThemeCatalogue.seedExamples() }
    reloadThemes()
    platform.revealInFileBrowser(Paths.themesDirectory)
  }
}

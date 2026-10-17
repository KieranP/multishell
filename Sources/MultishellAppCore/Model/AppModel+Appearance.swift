import MultishellCore

extension AppModel {
  public var themes: [Theme] { themeCatalogue.themes }

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

  /// Read off the main actor, the folder being read on every save in it. The
  /// engine keeps its own copy, so it is sent the theme again if it changed.
  public func reloadThemes() async {
    themeReloads += 1
    let reload = themeReloads
    let directory = themesDirectory
    let load = loadThemeCatalogue
    let catalogue = await runOnDispatch { load(directory) }
    // A reload begun after this one read the folder later; this would undo it.
    guard reload == themeReloads else { return }
    let shown = currentTheme
    take(catalogue)
    if currentTheme != shown { host.apply(currentTheme, appearance: workspace.appearance) }
  }

  /// Every newly broken file is named in one alert, and each only once, not
  /// again on a later save while it stays broken.
  func take(_ catalogue: ThemeCatalogue) {
    let shownFiles = Set(themeCatalogue.problems.map(\.fileName))
    themeCatalogue = catalogue
    let fresh = catalogue.problems.filter { !shownFiles.contains($0.fileName) }
    if !fresh.isEmpty {
      presentedError = .themeUnreadable(fresh.map(\.message).joined(separator: "\n\n"))
    }
  }

  public func revealThemesFolder() {
    // The watcher reloads after the copies land, so this need not.
    presentingFailure { try ThemeCatalogue.seedExamples(in: themesDirectory) }
    platform.revealInFileBrowser(themesDirectory)
  }
}

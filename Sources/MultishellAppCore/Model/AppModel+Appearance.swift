import MultishellCore

extension AppModel {
  public var currentTheme: Theme {
    workspace.appearance.theme(from: themes)
  }

  public func setTheme(_ id: Theme.ID) {
    store.setTheme(id)
    host.apply(currentTheme, appearance: workspace.appearance)
  }

  public func setFont(name: String?, size: Double) {
    store.setFont(name: name, size: size)
    host.apply(currentTheme, appearance: workspace.appearance)
  }

  /// The font picker's row for the family in force, system monospace for none.
  public var fontPickerID: String {
    workspace.appearance.fontName ?? FontDetection.systemID
  }

  /// Takes a font picker's row id, keeping the size; the divider is no choice.
  public func setFontName(_ id: String) {
    guard id != DetectionOption.dividerID else { return }
    setFont(name: id == FontDetection.systemID ? nil : id, size: workspace.appearance.fontSize)
  }

  /// Takes the terminal size slider's value, keeping the family.
  public func setFontSize(_ size: Double) {
    setFont(name: workspace.appearance.fontName, size: size)
  }

  public func setUIFontSize(_ size: Double) {
    store.setUIFontSize(size)
  }

  public func reloadThemes() {
    let catalogue = ThemeCatalogue.load()
    themes = catalogue.themes
    if let problem = catalogue.problems.first {
      presentedError = .themeUnreadable(problem)
    }
  }

  public func revealThemesFolder() {
    do {
      try ThemeCatalogue.seedExamples()
    } catch {
      present(error)
    }
    reloadThemes()
    platform.revealInFileBrowser(Paths.themesDirectory)
  }
}

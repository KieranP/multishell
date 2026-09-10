import Foundation
import MultishellCore

extension AppModel {
  public func setTheme(_ id: Theme.ID) {
    store.setTheme(id)
    host.apply(currentTheme, appearance: workspace.appearance)
  }

  public func setFont(name: String?, size: Double) {
    store.setFont(name: name, size: size)
    host.apply(currentTheme, appearance: workspace.appearance)
  }

  public func setUIFontSize(_ size: Double) {
    store.setUIFontSize(size)
  }

  public func reloadThemes() {
    let catalogue = ThemeCatalog.load()
    themes = catalogue.themes
    if let problem = catalogue.problems.first {
      presentedError = .themeUnreadable(problem)
    }
  }

  public func revealThemesFolder() {
    do {
      try ThemeCatalog.seedExamples()
    } catch {
      report(error)
    }
    reloadThemes()
    platform.revealInFileBrowser(Paths.themesDirectory)
  }

  /// Applies to the next terminal opened. Running ones keep the engine that
  /// started them, so nothing is killed by changing this.
  public func setTerminalEngine(_ engine: TerminalEngine) {
    store.setTerminalEngine(engine)
    host.engine = engine
  }

  public func setWorktreeDefaults(_ defaults: WorktreeSettings) {
    store.setWorktreeDefaults(defaults)
  }
}

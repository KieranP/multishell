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
      report(error)
    }
    reloadThemes()
    platform.revealInFileBrowser(Paths.themesDirectory)
  }

  public func setWorktreeDefaults(_ defaults: WorktreeSettings) {
    store.setWorktreeDefaults(defaults)
  }
}

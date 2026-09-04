import AppKit
import MultishellCore
import MultishellGitKit
import SwiftUI

// MARK: - Appearance

extension AppModel {
  func setTheme(_ id: Theme.ID) {
    store.setTheme(id)
    host.apply(currentTheme, appearance: workspace.appearance)
  }

  func setFont(name: String?, size: Double) {
    store.setFont(name: name, size: size)
    host.apply(currentTheme, appearance: workspace.appearance)
  }

  func setUIFontSize(_ size: Double) {
    store.setUIFontSize(size)
  }

  func reloadThemes() {
    let catalogue = ThemeCatalog.load()
    themes = catalogue.themes
    if let problem = catalogue.problems.first {
      presentedError = PresentedError(title: "A theme file could not be read", message: problem)
    }
  }

  func revealThemesFolder() {
    do {
      try ThemeCatalog.seedExamples()
    } catch {
      report(error)
    }
    reloadThemes()
    NSWorkspace.shared.activateFileViewerSelecting([Paths.themesDirectory])
  }

  /// Applies to the next terminal opened. Running ones keep the engine that
  /// started them, so nothing is killed by changing this.
  func setTerminalEngine(_ engine: TerminalEngine) {
    store.setTerminalEngine(engine)
    host.engine = engine
  }

  func setWorktreeDefaults(_ defaults: WorktreeSettings) {
    store.setWorktreeDefaults(defaults)
  }
}

// MARK: - Persistence

extension AppModel {
  /// Writes any pending change immediately. Called on quit, when the
  /// autosave debounce would otherwise lose the last few hundred ms.
  func saveNow() {
    pendingSave?.cancel()
    pendingSave = nil
    save()
  }

  /// Saves shortly after any workspace change, whoever made it.
  func observeForAutosave() {
    withObservationTracking {
      _ = store.workspace
    } onChange: {
      Task { @MainActor [weak self] in
        self?.scheduleSave()
        self?.observeForAutosave()
      }
    }
  }

  /// Terminal titles change on every prompt, so writes are coalesced.
  func scheduleSave() {
    pendingSave?.cancel()
    pendingSave = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      self?.save()
    }
  }

  func save() {
    do {
      try store.save()
    } catch {
      report(error)
    }
  }
}

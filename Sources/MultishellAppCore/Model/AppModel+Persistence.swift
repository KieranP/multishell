import Foundation
import MultishellCore

extension AppModel {
  /// Writes any pending change immediately. Called on quit, when the
  /// autosave debounce would otherwise lose the last few hundred ms.
  public func saveNow() {
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
      saveFailureReported = false
    } catch {
      // Every change schedules a save, so a full disk or a bad permission
      // would otherwise put the same alert up after each keystroke.
      guard !saveFailureReported else { return }
      saveFailureReported = true
      report(error)
    }
  }
}

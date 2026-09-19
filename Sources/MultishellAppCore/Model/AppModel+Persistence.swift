import Foundation
import MultishellCore

extension AppModel {
  /// Writes any pending change now, on this thread: called on quit, when
  /// the autosave debounce would otherwise lose the last few hundred ms.
  func saveNow() {
    pendingSave?.cancel()
    pendingSave = nil
    guard !yieldingToRunningInstance else { return }
    note(Result { try store.save() })
  }

  /// Saves shortly after any workspace change, whoever made it.
  func observeForAutosave() {
    withObservationTracking {
      _ = store.workspace
    } onChange: { [weak self] in
      Task { @MainActor in
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

  /// Encoded and written off the main actor, a stalled volume otherwise
  /// holding the window; the store keeps the writes in order.
  func save() {
    guard !yieldingToRunningInstance, let save = store.prepareSave() else { return }
    Task { @MainActor [weak self] in
      let outcome = await Self.offMain { Result { try save.run() } }
      self?.note(outcome)
    }
  }

  private func note(_ outcome: Result<Void, any Error>) {
    switch outcome {
    case .success:
      saveFailureReported = false
    case .failure(let error):
      // Every change schedules a save, so a full disk or a bad permission
      // would otherwise put the same alert up after each keystroke.
      guard !saveFailureReported else { return }
      saveFailureReported = true
      report(error)
    }
  }
}

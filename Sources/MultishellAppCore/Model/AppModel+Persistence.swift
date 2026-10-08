import Foundation
import MultishellCore

extension AppModel {
  /// Writes any pending change now, on this thread: called on quit, when
  /// the autosave debounce would otherwise lose the last few hundred ms.
  func saveNow() {
    pendingSave?.cancel()
    pendingSave = nil
    guard !isYieldingToRunningInstance else { return }
    recordSaveOutcome(Result { try store.save() })
  }

  /// Saves shortly after any workspace change, whoever made it. The loop only
  /// wakes on a change, so the model's `deinit` is what ends it.
  func observeForAutosave() {
    autosave?.cancel()
    let armedWith = store.workspace
    autosave = Task { @MainActor [weak self, store] in
      // The first value is read when the loop starts, so a change made before
      // then arrives as it; only the workspace as armed is no change.
      var isFirst = true
      for await workspace in Observations({ store.workspace }) {
        defer { isFirst = false }
        if isFirst, workspace == armedWith { continue }
        self?.scheduleSave()
      }
    }
  }

  private func scheduleSave() {
    pendingSave?.cancel()
    pendingSave = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      self?.saveOffMain()
    }
  }

  /// Encoded and written off the main actor, a stalled volume otherwise
  /// holding the window; the store keeps the writes in order.
  func saveOffMain() {
    guard !isYieldingToRunningInstance, let save = store.prepareSave() else { return }
    Task { @MainActor [weak self] in
      let outcome = await runOnDispatch { Result { try save.write() } }
      self?.recordSaveOutcome(outcome)
    }
  }

  private func recordSaveOutcome(_ outcome: Result<Void, any Error>) {
    switch outcome {
    case .success:
      hasReportedSaveFailure = false
    case .failure(let error):
      // Every change schedules a save, so a full disk or a bad permission
      // would otherwise put the same alert up after each keystroke.
      guard !hasReportedSaveFailure else { return }
      hasReportedSaveFailure = true
      present(error)
    }
  }
}

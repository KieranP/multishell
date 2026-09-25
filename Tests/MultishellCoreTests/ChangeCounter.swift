import Observation

@testable import MultishellCore

/// `replaceWorktrees` writes `workspace` twice, so firings between two reads of `changes`
/// count as one operation. A write of an equal value still fires.
@MainActor
final class ChangeCounter {
  private var counted = 0
  private var firings = 0
  private let store: WorkspaceStore

  init(_ store: WorkspaceStore) {
    self.store = store
    arm()
  }

  var changes: Int {
    if firings > 0 {
      counted += 1
      firings = 0
    }
    return counted
  }

  /// One registration answers one write, so it is made again from each.
  private func arm() {
    withObservationTracking {
      _ = store.workspace
    } onChange: {
      MainActor.assumeIsolated {
        self.firings += 1
        self.arm()
      }
    }
  }
}

import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func focusingASessionActivatesItsTab() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    store.openTab(in: worktree.id)

    store.focusSession(first.focusedSessionID)

    #expect(store.workspace.activeTab(in: worktree.id)?.id == first.id)
  }

  /// The engine reports focus on every click and showing, Ghostty's from inside a SwiftUI
  /// update, and every write re-runs the views and re-arms autosave.
  @Test func focusingTheSessionAlreadyFocusedWritesNothing() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    store.openTab(in: worktree.id)
    store.focusSession(first.focusedSessionID)

    let counter = ChangeCounter(store)
    store.focusSession(first.focusedSessionID)
    store.activateTab(first.id)
    #expect(counter.changes == 0)
  }
}

import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func closingTheLastPaneClosesItsTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!

    store.closeSession(tab.focusedSessionID)

    #expect(store.workspace.tabs.isEmpty)
    #expect(store.workspace.sessions.isEmpty)
  }

  @Test func closingOneSideOfASplitKeepsTheTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let original = tab.focusedSessionID
    let added = store.splitFocusedPane(of: tab.id, axis: .vertical)!

    store.closeSession(added.id)

    let survivor = store.workspace.tab(tab.id)
    #expect(survivor?.root == .terminal(original))
    #expect(survivor?.focusedSessionID == original)
    #expect(store.workspace.sessions.count == 1)
  }

  @Test func closingTheFocusedPaneFocusesTheOneThatTookItsPlace() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let middle = store.splitFocusedPane(of: tab.id, axis: .horizontal)!
    let last = store.splitFocusedPane(of: tab.id, axis: .vertical)!

    store.closeSession(last.id)

    #expect(store.workspace.tab(tab.id)?.focusedSessionID == middle.id)
  }

  @Test func closingTheFocusedFirstPaneOfANestedSplitFocusesItsSibling() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let middle = store.splitFocusedPane(of: tab.id, axis: .horizontal)!
    let last = store.splitFocusedPane(of: tab.id, axis: .vertical)!
    store.focusSession(middle.id)

    store.closeSession(middle.id)

    #expect(store.workspace.tab(tab.id)?.focusedSessionID == last.id)
  }

  @Test func closingTheFocusedFirstPaneFocusesTheNextOne() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let first = tab.focusedSessionID
    let second = store.splitFocusedPane(of: tab.id, axis: .horizontal)!
    store.splitFocusedPane(of: tab.id, axis: .horizontal)
    store.focusSession(first)

    store.closeSession(first)

    #expect(store.workspace.tab(tab.id)?.focusedSessionID == second.id)
  }

  @Test func splittingAddsAPaneToTheSameTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    store.splitFocusedPane(of: tab.id, axis: .horizontal)

    #expect(store.workspace.tabs.count == 1)
    #expect(store.workspace.tab(tab.id)?.sessionIDs.count == 2)
    #expect(store.workspace.tab(tab.id)?.isSplit == true)
  }

  @Test func splitWeightsAreWrittenAtAPath() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    store.splitFocusedPane(of: tab.id, axis: .horizontal)

    store.setSplitWeights([3, 1], at: [], ofTab: tab.id)

    guard case .split(_, _, let weights)? = store.workspace.tab(tab.id)?.root else {
      Issue.record("expected a split")
      return
    }
    #expect(weights == [3, 1])
  }

  /// The same refusal `setGroupWeights` makes: a zero or a NaN is a pane
  /// nothing can be laid out in, and the one writer never sends one.
  @Test func splitWeightsThatCannotLayOutAPaneAreRefused() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    store.splitFocusedPane(of: tab.id, axis: .horizontal)
    store.setSplitWeights([3, 1], at: [], ofTab: tab.id)

    for refused in [[0, 1], [1, .nan], [1, .infinity], [-1, 2]] as [[Double]] {
      store.setSplitWeights(refused, at: [], ofTab: tab.id)
      guard case .split(_, _, let weights)? = store.workspace.tab(tab.id)?.root else {
        Issue.record("expected a split")
        return
      }
      #expect(weights == [3, 1], "\(refused)")
    }
  }
}

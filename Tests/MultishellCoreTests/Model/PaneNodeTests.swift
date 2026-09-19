import Foundation
import Testing

@testable import MultishellCore

@Suite
struct PaneNodeTests {
  private let a = UUID()
  private let b = UUID()
  private let c = UUID()

  @Test func removingTheOnlyTerminalEmptiesTheTree() {
    #expect(PaneNode.terminal(a).removing(a) == nil)
  }

  @Test func removingAnAbsentTerminalChangesNothing() {
    let tree = PaneNode.terminal(a)
    #expect(tree.removing(b) == tree)
  }

  @Test func aSplitLeftWithOneChildCollapses() {
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), .terminal(b)])
    #expect(tree.removing(b) == .terminal(a))
  }

  @Test func nestedSplitsCollapseFromTheInsideOut() {
    let inner = PaneNode.split(axis: .horizontal, children: [.terminal(b), .terminal(c)])
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), inner])

    #expect(tree.removing(c) == .split(axis: .vertical, children: [.terminal(a), .terminal(b)]))
    #expect(tree.removing(c)?.removing(b) == .terminal(a))
  }

  @Test func splittingReplacesTheTargetLeaf() {
    let tree = PaneNode.terminal(a).splitting(a, with: b, axis: .vertical)
    #expect(tree == .split(axis: .vertical, children: [.terminal(a), .terminal(b)]))
  }

  @Test func splittingAlongTheSameAxisAddsASiblingAndHalvesItsShare() {
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), .terminal(b)])
    let result = tree.splitting(b, with: c, axis: .vertical)
    #expect(
      result
        == .split(
          axis: .vertical, children: [.terminal(a), .terminal(b), .terminal(c)],
          weights: [1, 0.5, 0.5]))
  }

  @Test func splittingAcrossTheAxisNests() {
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), .terminal(b)])
    let result = tree.splitting(b, with: c, axis: .horizontal)
    let nested = PaneNode.split(axis: .horizontal, children: [.terminal(b), .terminal(c)])
    #expect(result == .split(axis: .vertical, children: [.terminal(a), nested]))
  }

  @Test func weightsCanBeSetAtAPath() {
    let nested = PaneNode.split(axis: .horizontal, children: [.terminal(b), .terminal(c)])
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), nested])

    let updated = tree.settingWeights([3, 1], at: [1])
    guard case .split(_, let children, _) = updated, case .split(_, _, let inner) = children[1]
    else {
      Issue.record("shape changed")
      return
    }
    #expect(inner == [3, 1])
    #expect(tree.settingWeights([1, 2, 3], at: []) == tree, "mismatched count is ignored")
  }

  @Test func sessionIDsAreCollectedInOrder() {
    let inner = PaneNode.split(axis: .horizontal, children: [.terminal(b), .terminal(c)])
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), inner])
    #expect(tree.sessionIDs == [a, b, c])
  }

  @Test func removalKeepsWeightsAlignedWithChildren() {
    let tree = PaneNode.split(
      axis: .vertical, children: [.terminal(a), .terminal(b), .terminal(c)])
    guard case .split(_, let children, let weights)? = tree.removing(b) else {
      Issue.record("expected a split")
      return
    }
    #expect(children.count == weights.count)
  }
}

@Suite
struct PaneNodeEdgeTests {
  private let a = UUID()
  private let b = UUID()
  private let c = UUID()

  @Test func splittingAnUnknownTerminalChangesNothing() {
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), .terminal(b)])
    #expect(tree.splitting(c, with: UUID(), axis: .horizontal) == tree)
  }

  @Test func weightsStayAlignedThroughSplitAndRemove() {
    var tree = PaneNode.terminal(a)
    tree = tree.splitting(a, with: b, axis: .horizontal)
    tree = tree.splitting(b, with: c, axis: .horizontal)
    guard case .split(_, let children, let weights) = tree else {
      Issue.record("shape")
      return
    }
    #expect(children.count == 3 && weights == [1, 0.5, 0.5])

    guard case .split(_, let after, let afterWeights)? = tree.removing(a) else {
      Issue.record("shape")
      return
    }
    #expect(after == [.terminal(b), .terminal(c)] && afterWeights == [0.5, 0.5])
  }

  /// The enum case is public, so a split whose weights do not match its
  /// children can be built; the same-axis split indexes weights by child.
  @Test func splittingAMisalignedSplitRealignsInsteadOfTrapping() {
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), .terminal(b)], weights: [])
    guard case .split(_, let children, let weights) = tree.splitting(b, with: c, axis: .vertical)
    else {
      Issue.record("shape")
      return
    }
    #expect(children.count == 3)
    #expect(weights == [1, 0.5, 0.5])
  }

  @Test func settingWeightsAtABadPathIsIgnored() {
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), .terminal(b)])
    #expect(tree.settingWeights([2, 1], at: [5]) == tree)
    #expect(tree.settingWeights([2, 1], at: [0]) == tree, "a leaf has no weights")
  }
}

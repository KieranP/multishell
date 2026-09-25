import Foundation
import Testing

@testable import MultishellCore

extension PaneNodeTests {
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
    let tree = PaneNode.split(
      axis: .vertical, children: [.terminal(a), .terminal(b)], weights: [])
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

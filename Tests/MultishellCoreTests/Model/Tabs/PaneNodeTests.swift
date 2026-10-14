import Foundation
import Testing

@testable import MultishellCore

@Suite
struct PaneNodeTests {
  private let a = UUID()
  private let b = UUID()
  private let c = UUID()

  @Test func sessionIDsAreCollectedInOrder() {
    let inner = PaneNode.split(axis: .horizontal, children: [.terminal(b), .terminal(c)])
    let tree = PaneNode.split(axis: .vertical, children: [.terminal(a), inner])
    #expect(tree.sessionIDs == [a, b, c])
  }
}

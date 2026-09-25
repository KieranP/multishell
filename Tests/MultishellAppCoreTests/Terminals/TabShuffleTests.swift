import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// This has to agree with `WorkspaceStore.moveTab` exactly: a disagreement is a tab that
/// moves on every mouse event and never settles.
@Suite
struct TabShuffleTests {
  private let a = UUID()
  private let b = UUID()
  private let c = UUID()
  private var order: [UUID] { [a, b, c] }

  @Test func passingANeighbourReordersTheStrip() {
    #expect(TabShuffle.reorders(a, .after, of: b, in: order))
    #expect(TabShuffle.reorders(c, .before, of: a, in: order))
    #expect(TabShuffle.reorders(b, .after, of: c, in: order))
  }

  /// Where the tab already sits. Each of these is the same strip, and doing
  /// the move would write the workspace on every mouse event for nothing.
  @Test func aMoveThatChangesNothingIsNotOne() {
    #expect(!TabShuffle.reorders(a, .before, of: b, in: order), "already before b")
    #expect(!TabShuffle.reorders(b, .after, of: a, in: order), "already after a")
    #expect(!TabShuffle.reorders(c, .after, of: b, in: order), "already after b")
    #expect(!TabShuffle.reorders(a, .before, of: b, in: [a, b]))
    #expect(!TabShuffle.reorders(b, .after, of: a, in: [a, b]))
  }

  /// The pointer ends up over the tab that just slid under it, and reading
  /// that as an anchor to move it past is how a shuffle oscillates.
  @Test func aTabIsNotAnAnchorForItself() {
    #expect(!TabShuffle.reorders(a, .before, of: a, in: order))
    #expect(!TabShuffle.reorders(a, .after, of: a, in: order))
  }

  @Test func aTabOrAnAnchorThatIsNotInTheStripMovesNothing() {
    #expect(!TabShuffle.reorders(UUID(), .after, of: a, in: order))
    #expect(!TabShuffle.reorders(a, .after, of: UUID(), in: order))
    #expect(!TabShuffle.reorders(a, .after, of: b, in: []))
  }
}

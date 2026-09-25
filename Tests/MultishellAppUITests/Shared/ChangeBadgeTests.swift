import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct ChangeBadgeTests {
  /// `+12345 −6789 ~12 ↑3 ↓2`, which measured 138.5 pt at 13.
  private var large: WorktreeStatus {
    var status = WorktreeStatus()
    status.changedFiles = 40
    status.insertions = 12345
    status.deletions = 6789
    status.unscoredFiles = 12
    status.ahead = 3
    status.behind = 2
    return status
  }

  private func width(of status: WorktreeStatus, offered: CGFloat) -> CGFloat {
    let badge = ChangeBadge(
      status: status, theme: .multishellDark, size: 13, tint: .secondary)
    return NSHostingController(rootView: badge)
      .sizeThatFits(in: CGSize(width: offered, height: 40)).width
  }

  @Test func aLargeBadgeNarrowsToTheRoomItIsGiven() {
    let full = width(of: large, offered: 1000)

    #expect(width(of: large, offered: full - 1) < full - 1)
    #expect(width(of: large, offered: 100) <= 100)
  }
}

import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct DebugTimelineSlotWordingTests {
  @Test func aHoveredSlotSaysItsTimeWithoutTheDate() {
    let slot = DebugTimelineSlot(samples: [.sample(sequence: 0)])
    let year = String(Calendar.current.component(.year, from: slot.startedAt))
    #expect(!slot.startedAtText.isEmpty)
    #expect(!slot.startedAtText.contains(year))
  }
}

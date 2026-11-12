import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ReviewChipTests {
  @Test func staleLinesOutrankWaitingToBeSent() {
    #expect(ReviewChip.linesChanged.tone == .stale)
    #expect(ReviewChip.outdated.tone == .stale)
    #expect(ReviewChip.toSend.tone == .toSend)
    #expect(ReviewChip.sent(agentName: "Codex").tone == .sent)
  }

  @Test func aChipWhoseLinesNoLongerReadAsWrittenShowsTheQuote() {
    #expect(ReviewChip.linesChanged.showsQuote)
    #expect(ReviewChip.outdated.showsQuote)
    #expect(!ReviewChip.toSend.showsQuote)
    #expect(!ReviewChip.sent(agentName: "Codex").showsQuote)
  }
}

import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

struct ProcessGroupTests {
  @Test func aGroupIsOursOnlyWhileItsLeaderPredatesTheHangup() throws {
    var hangup = timeval()
    gettimeofday(&hangup, nil)
    let stranger = try WaitingShell()
    defer { stranger.terminate() }
    let group = stranger.pid

    #expect(!ProcessGroup.isStillOurs(hungUpAt: hangup, group: group))
    var later = timeval()
    gettimeofday(&later, nil)
    #expect(ProcessGroup.isStillOurs(hungUpAt: later, group: group))
    #expect(!ProcessGroup.isStillOurs(hungUpAt: later, group: deadPID()))
  }
}

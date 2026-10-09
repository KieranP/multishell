import Foundation
import Testing

@testable import MultishellProcess

@Suite
struct UnixSocketServerAcceptOutcomeTests {
  /// The read source on a listening socket is level-triggered, so a pending
  /// connection nothing accepts fires the handler again at once.
  @Test func eachAcceptErrorRetriesWaitsOrBacksOff() {
    #expect(UnixSocketServer.AcceptOutcome(errno: EAGAIN) == .waitForNextEvent)
    #expect(UnixSocketServer.AcceptOutcome(errno: EWOULDBLOCK) == .waitForNextEvent)
    #expect(UnixSocketServer.AcceptOutcome(errno: EINTR) == .retryNow, "a signal is not an answer")
    #expect(
      UnixSocketServer.AcceptOutcome(errno: ECONNABORTED) == .retryNow,
      "the peer went; the next one is still waiting",
    )
    #expect(
      UnixSocketServer.AcceptOutcome(errno: EMFILE) == .outOfResources,
      "returning here spins the queue against a backlog that never clears",
    )
    #expect(UnixSocketServer.AcceptOutcome(errno: ENFILE) == .outOfResources)
    #expect(
      UnixSocketServer.AcceptOutcome(errno: EINVAL) == .waitForNextEvent,
      "unknown: wait, do not spin",
    )
  }
}

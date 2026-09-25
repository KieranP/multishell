import Foundation
import Testing

@testable import MultishellProcess

extension UnixSocketServerTests {
  /// The read source on a listening socket is level-triggered, so a pending
  /// connection nothing accepts fires the handler again at once.
  @Test func onlyRunningOutOfNothingEndsTheAcceptLoop() {
    #expect(UnixSocketServer.AcceptOutcome(errno: EAGAIN) == .drained)
    #expect(UnixSocketServer.AcceptOutcome(errno: EWOULDBLOCK) == .drained)
    #expect(UnixSocketServer.AcceptOutcome(errno: EINTR) == .again, "a signal is not an answer")
    #expect(
      UnixSocketServer.AcceptOutcome(errno: ECONNABORTED) == .again,
      "the peer went; the next one is still waiting")
    #expect(
      UnixSocketServer.AcceptOutcome(errno: EMFILE) == .outOfDescriptors,
      "returning here spins the queue against a backlog that never clears")
    #expect(UnixSocketServer.AcceptOutcome(errno: ENFILE) == .outOfDescriptors)
    #expect(
      UnixSocketServer.AcceptOutcome(errno: EINVAL) == .drained, "unknown: stop, do not spin")
  }
}

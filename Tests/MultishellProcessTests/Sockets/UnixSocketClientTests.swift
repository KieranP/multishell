import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct UnixSocketClientTests {
  @Test func aClientWithNobodyListeningGetsAnErrorNotAHang() {
    let path = Scratch.socketPath("srv")
    do {
      try UnixSocketClient.send("hello\n", to: path)
      Issue.record("sent to nobody")
    } catch let failure as SocketFailure {
      if case .system(let operation, _) = failure.kind {
        #expect(operation == "connect")
      } else {
        Issue.record("wrong kind: \(failure.kind)")
      }
    } catch {
      Issue.record("wrong error: \(error)")
    }
  }
}

import Foundation
import Testing

@testable import MultishellProcess

@Suite
struct ThreadUsageTests {
  @Test func aNamedThreadIsReadWithItsNameAndTheCPUItSpent() throws {
    let started = DispatchSemaphore(value: 0)
    let finish = DispatchSemaphore(value: 0)
    let thread = Thread {
      var spin = 0.0
      for index in 0..<5_000_000 { spin += sqrt(Double(index)) }
      precondition(spin > 0)
      started.signal()
      finish.wait()
    }
    thread.name = "usage-probe"
    thread.start()
    started.wait()
    defer { finish.signal() }

    let threads = ThreadUsage.ofThisProcess(mainThreadID: ThreadUsage.currentThreadID())
    let probe = try #require(threads.first { $0.name == "usage-probe" })

    #expect(probe.cpuTime > .milliseconds(1))
    #expect(!probe.isMain)
  }

  @Test func theThreadNamedAsMainIsTheOneMarkedMain() {
    let current = ThreadUsage.currentThreadID()
    let threads = ThreadUsage.ofThisProcess(mainThreadID: current)

    #expect(threads.filter(\.isMain).map(\.id) == [current])
  }

  @Test func everyThreadHasItsOwnID() {
    let threads = ThreadUsage.ofThisProcess(mainThreadID: 0)
    #expect(Set(threads.map(\.id)).count == threads.count)
  }
}

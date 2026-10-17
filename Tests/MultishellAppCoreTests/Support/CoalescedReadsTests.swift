import Testing

@testable import MultishellAppCore

@Suite
struct CoalescedReadsTests {
  @Test func readsAskedForWhileOneRunsRunOnceWhenItFinishes() {
    var reads = CoalescedReads<String>()
    var started = 0
    for _ in 0..<3 {
      reads.start("a") {
        started += 1
        return Task {}
      }
    }

    let isAskedAgain = reads.finish("a")
    #expect(started == 1)
    #expect(isAskedAgain)
    #expect(!reads.isRunning("a"))
  }

  @Test func cancellingForgetsTheRunningReadAndTheOneAskedFor() {
    var reads = CoalescedReads<String>()
    reads.start("a") { Task {} }
    reads.start("a") { Task {} }
    reads.start("b") { Task {} }

    reads.cancel { $0 == "a" }

    #expect(!reads.isRunning("a"))
    #expect(reads.isRunning("b"))
    reads.start("a") { Task {} }
    let isAskedAgain = reads.finish("a")
    #expect(!isAskedAgain)
  }
}

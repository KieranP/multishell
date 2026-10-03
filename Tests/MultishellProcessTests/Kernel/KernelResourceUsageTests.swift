import Foundation
import Testing

@testable import MultishellProcess

@Suite
struct KernelResourceUsageTests {
  private func processClock() -> Duration {
    var time = timespec()
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &time)
    return .seconds(time.tv_sec) + .nanoseconds(time.tv_nsec)
  }

  /// A tick read as a nanosecond is 41 times short on Apple silicon, which a
  /// factor of two either side still tells apart.
  @Test func theCPUTimeOfThisProcessAgreesWithItsOwnClock() throws {
    var spin = 0.0
    for index in 0..<20_000_000 { spin += sqrt(Double(index)) }
    #expect(spin > 0)
    let clock = processClock()
    let usage = try #require(KernelResourceUsage.of(ProcessInfo.processInfo.processIdentifier))

    #expect(usage.cpuTime > clock / 2)
    #expect(usage.cpuTime < clock * 2)
    #expect(usage.footprint > 1 << 20)
  }

  @Test func aPidNothingHoldsHasNoUsage() {
    #expect(KernelResourceUsage.of(999_999_999) == nil)
  }
}

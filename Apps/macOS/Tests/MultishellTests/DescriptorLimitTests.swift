import Foundation
import Testing

@testable import Multishell

@Suite
struct DescriptorLimitTests {
  @Test func raisingNeverLowersAndReachesTheKernelsCeiling() {
    var before = rlimit()
    getrlimit(RLIMIT_NOFILE, &before)

    let after = DescriptorLimit.raise()

    #expect(after >= Int(clamping: before.rlim_cur))
    #expect(after >= Int(clamping: min(before.rlim_max, rlim_t(OPEN_MAX))))
    var now = rlimit()
    getrlimit(RLIMIT_NOFILE, &now)
    #expect(Int(clamping: now.rlim_cur) == after)
  }
}

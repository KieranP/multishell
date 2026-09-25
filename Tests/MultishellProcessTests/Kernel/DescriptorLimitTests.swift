import Foundation
import Testing

@testable import MultishellProcess

@Suite
struct DescriptorLimitTests {
  @Test func raisingNeverLowersAndReachesTheCeiling() {
    var before = rlimit()
    #expect(getrlimit(DescriptorLimit.resource, &before) == 0)

    let after = DescriptorLimit.raise()

    #expect(after >= Int(clamping: before.rlim_cur))
    #expect(after >= Int(clamping: DescriptorLimit.ceiling(of: before)) || after == -1)
    var now = rlimit()
    getrlimit(DescriptorLimit.resource, &now)
    #expect(Int(clamping: now.rlim_cur) == after)
  }
}

import Foundation
import Testing

@testable import MultishellProcess

@Suite
struct KernelProcessTableTests {
  @Test func theParentAndNameOfThisProcessAreKnown() {
    let me = ProcessInfo.processInfo.processIdentifier
    #expect(KernelProcessTable.parent(of: me) == getppid())
    #expect(KernelProcessTable.name(of: me)?.isEmpty == false)
  }

  @Test func launchdIsKnownAndAPidNothingHoldsIsNot() {
    #expect(KernelProcessTable.name(of: 1) != nil)
    #expect(KernelProcessTable.parent(of: 999_999_999) == nil)
  }
}

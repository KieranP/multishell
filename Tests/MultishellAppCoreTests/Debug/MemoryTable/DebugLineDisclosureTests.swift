import Testing

@testable import MultishellAppCore

@Suite
struct DebugLineDisclosureTests {
  @Test func onlyALineWithSomethingUnderItIsExpandable() {
    #expect(!DebugLineDisclosure.notExpandable.isExpandable)
    #expect(DebugLineDisclosure.collapsed.isExpandable)
    #expect(DebugLineDisclosure.expanded.isExpandable)
  }
}

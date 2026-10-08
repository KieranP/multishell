import Testing

@testable import MultishellAppCore

@Suite
struct DebugRowDisclosureTests {
  @Test func onlyALineWithSomethingUnderItIsExpandable() {
    #expect(!DebugRowDisclosure.notExpandable.isExpandable)
    #expect(DebugRowDisclosure.collapsed.isExpandable)
    #expect(DebugRowDisclosure.expanded.isExpandable)
  }
}

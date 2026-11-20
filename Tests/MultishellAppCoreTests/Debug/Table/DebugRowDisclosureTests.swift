import Testing

@testable import MultishellAppCore

@Suite
struct DebugRowDisclosureTests {
  @Test func onlyACollapsedOrExpandedRowIsExpandable() {
    #expect(!DebugRowDisclosure.notExpandable.isExpandable)
    #expect(DebugRowDisclosure.collapsed.isExpandable)
    #expect(DebugRowDisclosure.expanded.isExpandable)
  }
}

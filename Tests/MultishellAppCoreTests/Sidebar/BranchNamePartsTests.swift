import Testing

@testable import MultishellAppCore

@Suite
struct BranchNamePartsTests {
  @Test func aBranchSplitsAfterItsLastSlash() {
    let parts = BranchNameParts("team/feat/dashboard")
    #expect(parts.prefix == "team/feat/")
    #expect(parts.leaf == "dashboard")
  }

  @Test func aNameWithoutASlashIsAllLeaf() {
    let parts = BranchNameParts("main")
    #expect(parts.prefix == "")
    #expect(parts.leaf == "main")
  }
}

import Testing

@testable import MultishellAppCore

@Suite
struct BranchNamePartsTests {
  @Test func aBranchSplitsAfterItsLastSlash() {
    let parts = BranchNameParts("team/feat/dashboard")
    #expect(parts.prefix == "team/feat/")
    #expect(parts.leaf == "dashboard")
  }

  @Test func aLeafStartingWithACombiningMarkStillSplitsAtTheSlashBeforeIt() {
    let parts = BranchNameParts("kp/\u{0301}x")
    #expect(parts.prefix == "kp/")
    #expect(parts.leaf == "\u{0301}x")
  }

  @Test func aNameWithoutASlashIsAllLeaf() {
    let parts = BranchNameParts("main")
    #expect(parts.prefix == "")
    #expect(parts.leaf == "main")
  }
}

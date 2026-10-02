import Testing

@testable import MultishellAppCore

@Suite
struct WorktreePathClaimsTests {
  private let firstTree = "/trees/a"
  private let secondTree = "/trees/b"

  @Test func twoCreatesNamingOnePathEachLetGoOfTheirOwnClaim() {
    var claims = WorktreePathClaims()
    claims.claim(firstTree)
    claims.claim(firstTree)
    claims.claim(secondTree)
    #expect(claims.isClaimed(firstTree) && claims.isClaimed(secondTree))

    claims.release(firstTree)
    #expect(claims.isClaimed(firstTree), "the second create still holds it")
    claims.release(firstTree)
    #expect(!claims.isClaimed(firstTree))
    #expect(claims.isClaimed(secondTree))
  }

  @Test func releasingAPathNothingClaimedChangesNothing() {
    var claims = WorktreePathClaims()
    claims.release(firstTree)
    #expect(!claims.isClaimed(firstTree))
  }
}

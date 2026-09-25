import Testing

@testable import MultishellAppCore

@Suite
struct WorktreePathClaimsTests {
  private let a = "/trees/a"
  private let b = "/trees/b"

  @Test func twoCreatesNamingOnePathEachLetGoOfTheirOwnClaim() {
    var claims = WorktreePathClaims()
    claims.claim(a)
    claims.claim(a)
    claims.claim(b)
    #expect(claims.isClaimed(a) && claims.isClaimed(b))

    claims.release(a)
    #expect(claims.isClaimed(a), "the second create still holds it")
    claims.release(a)
    #expect(!claims.isClaimed(a))
    #expect(claims.isClaimed(b))
  }

  @Test func releasingAPathNothingClaimedChangesNothing() {
    var claims = WorktreePathClaims()
    claims.release(a)
    #expect(!claims.isClaimed(a))
  }
}

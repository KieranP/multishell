import Testing

@testable import MultishellAppCore

@Suite
struct AllChangesStepOriginTests {
  @Test func aBoxInTheClipIsWhereAStepCountsFrom() {
    let origin = AllChangesStepOrigin(boxedTop: 250, clipTop: 200, clipHeight: 300)

    #expect(origin == AllChangesStepOrigin(top: 250, isBoxed: true))
  }

  @Test func aBoxScrolledOutOfTheClipLeavesTheClipsTopToCountFrom() {
    #expect(
      AllChangesStepOrigin(boxedTop: 40, clipTop: 2_000, clipHeight: 300)
        == AllChangesStepOrigin(top: 2_000, isBoxed: false)
    )
    #expect(
      AllChangesStepOrigin(boxedTop: 2_400, clipTop: 2_000, clipHeight: 300)
        == AllChangesStepOrigin(top: 2_000, isBoxed: false)
    )
  }

  @Test func withNothingBoxedAStepCountsFromTheClipsTop() {
    #expect(
      AllChangesStepOrigin(boxedTop: nil, clipTop: 80, clipHeight: 300)
        == AllChangesStepOrigin(top: 80, isBoxed: false)
    )
  }
}

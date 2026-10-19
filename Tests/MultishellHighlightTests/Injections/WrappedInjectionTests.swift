import Testing

@testable import MultishellHighlight

@Suite
struct WrappedInjectionTests {
  @Test func aCommentOpenedLastAndNeverClosedIsLeftOpen() {
    #expect(WrappedInjection.leavesCommentOpen("color: red; /* a */ /* b"))
  }

  @Test func aCommentClosedRightBeforeAStarIsNotLeftOpen() {
    #expect(!WrappedInjection.leavesCommentOpen("color: red; /* a */* b"))
  }

  @Test func aCommentWhoseOpenerSharesItsStarWithACloserIsLeftOpen() {
    #expect(WrappedInjection.leavesCommentOpen("color: red; /*/ b"))
  }
}

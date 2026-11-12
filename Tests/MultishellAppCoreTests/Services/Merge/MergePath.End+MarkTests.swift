import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergePathEndMarkTests {
  @Test func anOpenPullRequestEndsOnTheOpenGlyphGreenOnlyWhereItMergesNow() {
    #expect(MergePath.sample(.sample(), checks: []).end.mark.shape == .open)
    #expect(MergePath.sample(.sample(), checks: []).end.mark.tone == .readyToMerge)
    #expect(
      MergePath.sample(.sample(), checks: [.sample(status: .running)]).end.mark.tone == .secondary,
      "Merge When Ready",
    )
    #expect(
      MergePath.sample(.sample(autoMergesWhenReady: true), checks: []).end.mark.tone == .secondary,
      "Cancel Auto-Merge",
    )
    #expect(
      MergePath.sample(.sample(), checks: [], isMergeTaken: true).end.mark.tone == .secondary
    )
    #expect(MergePath.sample(.sample(review: .required), checks: []).end.mark.tone == .tertiary)
  }

  @Test func aSettledPullRequestEndsOnTheGlyphOfWhatBecameOfIt() {
    let merged = MergePath.sample(.sample(state: .merged), checks: []).end.mark
    let closed = MergePath.sample(.sample(state: .closed), checks: []).end.mark
    #expect(merged.shape == .merged)
    #expect(merged.tone == .merged)
    #expect(closed.shape == .closed)
    #expect(closed.tone == .secondary)
    #expect(merged.corner == nil)
  }
}

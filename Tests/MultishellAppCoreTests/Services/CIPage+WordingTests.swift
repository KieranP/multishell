import Testing

@testable import MultishellAppCore

@Suite
struct CIPageWordingTests {
  @Test func anUnpushedBranchSaysNothingRunsUntilItIsPushed() {
    let text = CIPage.notPushed(branch: "feat").emptyText
    #expect(text?.title == "No runs of feat")
    #expect(text?.detail == "Nothing runs on a branch until it is pushed.")
  }

  @Test func aShownRunSaysNothing() {
    #expect(CIPage.run(.sample()).emptyText == nil)
  }
}

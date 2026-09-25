import Testing

@testable import MultishellGitKit

@Suite
struct MergedBranchParserTests {
  @Test func mergedBranchesAreEachLineAsWrittenSkippingBlankOnes() {
    let merged = MergedBranchParser.parse("main\nfeat/tabs\n(wip)\n\n")
    #expect(merged == ["main", "feat/tabs", "(wip)"])
  }
}

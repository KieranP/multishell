import Testing

@testable import MultishellGitKit

@Suite
struct PatchEquivalenceParserTests {
  @Test func aBranchIsPatchEquivalentOnlyWhenNoCommitIsStillMissing() {
    #expect(PatchEquivalenceParser.parse("- ab1\n- cd2\n"))
    #expect(!PatchEquivalenceParser.parse("- ab1\n+ cd2\n"))
    #expect(!PatchEquivalenceParser.parse("+ ab1\n"))
    // Nothing printed is not an answer: `git cherry` skips merge commits, so
    // a branch whose every commit ahead is a merge prints exactly this.
    #expect(!PatchEquivalenceParser.parse(""))
    #expect(!PatchEquivalenceParser.parse("\n  \n"))
  }
}

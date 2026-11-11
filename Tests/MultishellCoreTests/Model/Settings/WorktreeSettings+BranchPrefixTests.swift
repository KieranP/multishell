import Testing

@testable import MultishellCore

@Suite
struct WorktreeSettingsBranchPrefixTests {
  @Test func theBranchPrefixIsAppliedOnce() {
    let settings = WorktreeSettings(branchPrefix: "kieran/")
    #expect(settings.qualifiedBranch("tabs") == "kieran/tabs")
    #expect(settings.qualifiedBranch("kieran/tabs") == "kieran/tabs")
  }

  @Test func aTypedPrefixFollowedByACombiningMarkIsNotAddedAgain() {
    let settings = WorktreeSettings(branchPrefix: "kp/")
    #expect(settings.qualifiedBranch("kp/\u{0301}foo") == "kp/\u{0301}foo")
  }

  @Test func anEmptyPrefixLeavesTheNameAlone() {
    #expect(WorktreeSettings().qualifiedBranch(" tabs ") == "tabs")
  }
}

import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct WorktreeSettingsExampleBranchTests {
  @Test func theExampleCarriesThePrefix() {
    let settings = WorktreeSettings(worktreeDirectory: "", branchPrefix: "team/")
    #expect(settings.exampleBranch == "team/tabs")
  }

  @Test func withNoPrefixTheExampleIsTheBareName() {
    let settings = WorktreeSettings(worktreeDirectory: "", branchPrefix: "")
    #expect(settings.exampleBranch == "tabs")
  }
}

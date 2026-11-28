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

  @Test func theCaptionShowsWhatATypedNameBecomesUnderThePrefix() {
    let settings = WorktreeSettings(worktreeDirectory: "", branchPrefix: "team/")
    #expect(settings.prefixExampleCaption == "Typing tabs creates team/tabs.")
  }

  @Test func theCaptionShowsThePrefixTrimmedAsCreationAppliesIt() {
    let settings = WorktreeSettings(worktreeDirectory: "", branchPrefix: "team/ ")
    #expect(settings.prefixExampleCaption == "Typing tabs creates team/tabs.")
  }

  @Test func aPrefixOfSpacesHasNoCaption() {
    let settings = WorktreeSettings(worktreeDirectory: "", branchPrefix: "  ")
    #expect(settings.prefixExampleCaption == nil)
  }

  @Test func withNoPrefixThereIsNoCaption() {
    let settings = WorktreeSettings(worktreeDirectory: "", branchPrefix: "")
    #expect(settings.prefixExampleCaption == nil)
  }
}

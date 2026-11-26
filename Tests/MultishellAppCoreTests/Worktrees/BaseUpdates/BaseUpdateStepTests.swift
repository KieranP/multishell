import MultishellCore
import Testing

@testable import MultishellAppCore

struct BaseUpdateStepTests {
  @Test func eachStepSaysWhatRunsAndAnAbortNamesNoMethod() {
    #expect(BaseUpdateStep.checking.help == "Checking the worktree before updating it")
    #expect(BaseUpdateStep.updating(.merge).help == "Merging from the base")
    #expect(BaseUpdateStep.updating(.rebase).help == "Rebasing onto the base")
    #expect(BaseUpdateStep.aborting.help == "Putting the branch back where it was")
  }

  @Test func eachStepHasACommandLineWord() {
    #expect(
      [BaseUpdateStep.checking, .updating(.merge), .updating(.rebase), .aborting]
        .map(\.commandLineName) == ["checking", "merging", "rebasing", "aborting"]
    )
  }
}

import MultishellCore
import Testing

@testable import MultishellAppCore

struct BaseUpdateStepCommandNameTests {
  @Test func eachStepHasACommandLineWord() {
    #expect(
      [BaseUpdateStep.checking, .fetching, .updating(.merge), .updating(.rebase), .aborting]
        .map(\.commandName) == ["checking", "fetching", "merging", "rebasing", "aborting"]
    )
  }
}

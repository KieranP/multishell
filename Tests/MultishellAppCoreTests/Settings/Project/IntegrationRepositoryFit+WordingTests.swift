import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct IntegrationRepositoryFitWordingTests {
  @Test func eachKnownMisfitIsSaidAndAnUnknownOneIsNot() {
    #expect(
      IntegrationRepositoryFit.notHosted.text(of: .gitHub)
        == "This repository is not on GitHub, so nothing is read."
    )
    #expect(
      IntegrationRepositoryFit.notConfigured.text(of: .circleCI)
        == "This repository has no CircleCI configuration, so no runs are read."
    )
    #expect(IntegrationRepositoryFit.unknown.text(of: .gitHub) == nil)
  }
}

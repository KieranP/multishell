import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ServiceIntegrationSettingsWordingTests {
  @Test func eachIntegrationHasItsOwnToggleAndInfo() {
    #expect(ServiceIntegration.gitHub.settingsLabel == "Show GitHub pull requests")
    #expect(ServiceIntegration.circleCI.settingsLabel == "Show CircleCI runs")
    #expect(ServiceIntegration.circleCI.settingsInfo.contains("circleci"))
  }
}

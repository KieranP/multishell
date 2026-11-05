import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ServiceIntegrationSettingsPageOrderTests {
  @Test func theIntegrationsPageListsEveryIntegrationOnceGitHubFirst() {
    #expect(ServiceIntegration.settingsPageOrder.first == .gitHub)
    #expect(Set(ServiceIntegration.settingsPageOrder) == Set(ServiceIntegration.allCases))
    #expect(ServiceIntegration.settingsPageOrder.count == ServiceIntegration.allCases.count)
  }
}

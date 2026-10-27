import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ProjectSettingsIntegrationsTests {
  @Test func everyIntegrationIsOnUntilTurnedOff() {
    var settings = ProjectSettings()
    #expect(ServiceIntegration.allCases.allSatisfy(settings.enables))

    settings.setIntegration(.gitHub, isEnabled: false)

    #expect(!settings.enables(.gitHub))
    #expect(settings.enables(.circleCI))
  }

  @Test func turningIntegrationsOffInAnyOrderWritesOneList() {
    var first = ProjectSettings()
    first.setIntegration(.gitHub, isEnabled: false)
    first.setIntegration(.circleCI, isEnabled: false)
    first.setIntegration(.gitHub, isEnabled: false)
    var second = ProjectSettings()
    second.setIntegration(.circleCI, isEnabled: false)
    second.setIntegration(.gitHub, isEnabled: false)

    #expect(first.disabledIntegrations == [.circleCI, .gitHub])
    #expect(first == second)
  }

  @Test func turningAnIntegrationBackOnLeavesTheSettingsAsTheyWere() {
    var settings = ProjectSettings()
    settings.setIntegration(.circleCI, isEnabled: false)
    settings.setIntegration(.circleCI, isEnabled: true)
    #expect(settings == ProjectSettings())
  }

  @Test func anIntegrationANewerBuildNamedCostsThatEntryAlone() throws {
    let settings = try decodeJSON(
      ProjectSettings.self,
      #"{ "disabledIntegrations": ["gitlab", "github", 7] }"#,
    )
    #expect(settings.disabledIntegrations == [.gitHub])
    #expect(try decodeJSON(ProjectSettings.self, "{}").disabledIntegrations == [])
  }
}

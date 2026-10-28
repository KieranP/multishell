import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelFilesPanelTests {
  @Test func thePanelDrawsTheScopeSwitchOverItsChangesListAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.featureInChangesList()
    #expect(harness.model.filesPanelShowsChangeScopeSwitch)

    harness.model.setFilesPanelMode(.files)

    #expect(!harness.model.filesPanelShowsChangeScopeSwitch)
  }
}

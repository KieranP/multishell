import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelActionsInForceTests {
  @Test func onlyAFilledInOwnActionStandsInForTheFilesOfItsName() {
    let harness = Harness()
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Deploy", command: "")]),
      for: harness.project,
    )
    #expect(!harness.model.ownActionStandsIn(forFileAction: "Deploy", in: harness.project))

    harness.model.setActionCommand("bin/deploy --mine", at: 0, in: harness.project)

    #expect(harness.model.ownActionStandsIn(forFileAction: "Deploy", in: harness.project))
  }

  @Test func anUnfilledRowNamedForAFilesActionLeavesThatActionInForce() async throws {
    let harness = Harness()
    try #"{ "actions": [ { "name": "Deploy", "command": "bin/deploy" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setTrustsSharedSettings(true, for: harness.project)

    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Deploy", command: "")]).with { settings in
        settings.trustDecisions = harness.model.ownSettings(of: harness.project).trustDecisions
      },
      for: harness.project,
    )

    #expect(harness.model.actionMenu(for: harness.main)?.items.map(\.name) == ["Deploy"])
  }

  @Test func aFileRowLeavesItsKeysToAnOwnRowOfItsNameEvenUnfilled() async throws {
    let harness = Harness()
    try #"{ "actions": [ { "name": "Serve", "command": "npm start" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    #expect(harness.model.fileRowShowsKeys(forFileAction: "Serve", in: harness.project))

    harness.model.addAction(to: harness.project)
    harness.model.setActionName("Serve", at: 0, in: harness.project)

    #expect(!harness.model.fileRowShowsKeys(forFileAction: "Serve", in: harness.project))
  }
}

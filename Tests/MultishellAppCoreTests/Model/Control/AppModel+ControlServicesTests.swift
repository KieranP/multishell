import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite @MainActor
struct AppModelControlServicesTests {
  private func harnessWithARunOnFeature() -> Harness {
    let harness = Harness()
    harness.model.select(harness.main)
    var services = WorktreeServices()
    services.ciRun = .sample()
    services.ciIntegration = .circleCI
    harness.model.remoteState.worktrees[harness.feature.id] = services
    return harness
  }

  @Test func showingAWorktreesCIPageSelectsItAndOpensThePanelOnIt() async {
    let harness = harnessWithARunOnFeature()
    let id = ControlID.worktree(harness.feature.id)

    let reply = await harness.messageSource.ask(.showServicePage(.ciRuns, worktree: id))

    #expect(reply == .done)
    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
    #expect(harness.model.showsFilesPanel)
    #expect(harness.model.workspace.filesPanelMode == .ciRuns)
  }

  @Test func aWorktreeWithNoRunHasNoCIPageToShow() async {
    let harness = harnessWithARunOnFeature()

    let reply = await harness.messageSource.ask(.showServicePage(.ciRuns, worktree: nil))

    #expect(reply == .refused(.noServicePage(.ciRuns, id: ControlID.worktree(harness.main.id))))
    #expect(!harness.model.showsFilesPanel)
  }

  @Test func aWorktreeWithARunButNoPullRequestHasNoPullRequestPageToShow() async {
    let harness = harnessWithARunOnFeature()
    let id = ControlID.worktree(harness.feature.id)

    let reply = await harness.messageSource.ask(.showServicePage(.pullRequest, worktree: id))

    #expect(reply == .refused(.noServicePage(.pullRequest, id: id)))
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
  }

  @Test func aStandInItCannotReadIsRefusedSayingWhere() async {
    let harness = Harness()

    let reply = await harness.messageSource.ask(
      .standInServices(json: #"{"ciRuns": [{"id": "r", "branch": "b"}]}"#)
    )

    guard case .serviceStandInUnreadable(let reason)? = reply?.refusal else {
      Issue.record("not refused: \(String(describing: reply))")
      return
    }
    #expect(reason.contains("ciRuns.0"), "\(reason)")
  }

  @Test func withTheMainWindowShutNoPageOpens() async {
    let harness = harnessWithARunOnFeature()
    harness.platform.workspaceWindowSize = nil

    let reply = await harness.messageSource.ask(
      .showServicePage(.ciRuns, worktree: ControlID.worktree(harness.feature.id))
    )

    #expect(reply == .refused(.noWindow))
    #expect(!harness.model.showsFilesPanel)
  }

  @Test func aMainWindowCoveredByAnotherStillOpensThePage() async {
    let harness = harnessWithARunOnFeature()
    harness.platform.isWorkspaceWindowVisible = false

    let reply = await harness.messageSource.ask(
      .showServicePage(.ciRuns, worktree: ControlID.worktree(harness.feature.id))
    )

    #expect(reply == .done)
    #expect(harness.model.showsFilesPanel)
  }

  @Test func aWorktreeIDNoWorktreeHasIsRefusedByNameWithTheWindowShut() async {
    let harness = harnessWithARunOnFeature()
    harness.platform.workspaceWindowSize = nil

    let reply = await harness.messageSource.ask(
      .showServicePage(.ciRuns, worktree: "w-deadbeef")
    )

    #expect(reply == .refused(.noWorktree(id: "w-deadbeef")))
  }
}

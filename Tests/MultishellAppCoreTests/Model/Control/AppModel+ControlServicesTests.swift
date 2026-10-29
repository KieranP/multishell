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

  @Test func showingAWorktreesServicesOpensItsRowsPopoverAndExpandsItsProject() async {
    let harness = harnessWithARunOnFeature()
    harness.store.setExpanded(false, forProject: harness.project.id)
    let id = ControlID.worktree(harness.feature.id)

    let reply = await harness.messageSource.ask(.showServices(worktree: id))

    #expect(reply == .done)
    #expect(harness.model.servicesPopoverWorktreeID == harness.feature.id)
    #expect(harness.project.isExpanded)
  }

  @Test func aWorktreeWithNoPullRequestOrRunHasNoPopoverToShow() async {
    let harness = harnessWithARunOnFeature()

    let reply = await harness.messageSource.ask(.showServices(worktree: nil))

    #expect(reply == .refused(.noServices(id: ControlID.worktree(harness.main.id))))
    #expect(harness.model.servicesPopoverWorktreeID == nil)
  }

  @Test func theOpenPopoverIsListedAndDismissedOrHidden() async {
    let harness = harnessWithARunOnFeature()
    let id = ControlID.worktree(harness.feature.id)
    _ = await harness.messageSource.ask(.showServices(worktree: id))

    let dismissed = await harness.messageSource.ask(.dismissPresentation)
    let isUpAfterDismiss = harness.model.servicesPopoverWorktreeID != nil
    _ = await harness.messageSource.ask(.showServices(worktree: id))
    let hidden = await harness.messageSource.ask(.hideView(.services))

    #expect(dismissed?.outputFields["kind"] as? String == "services-popover")
    #expect(!isUpAfterDismiss)
    #expect(hidden == .done)
    #expect(harness.model.servicesPopoverWorktreeID == nil)
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

  @Test func withTheMainWindowShutNoPopoverOpens() async {
    let harness = harnessWithARunOnFeature()
    harness.platform.isWorkspaceWindowVisible = false

    let reply = await harness.messageSource.ask(
      .showServices(worktree: ControlID.worktree(harness.feature.id))
    )

    #expect(reply == .refused(.noWindow))
    #expect(harness.model.servicesPopoverWorktreeID == nil)
  }
}

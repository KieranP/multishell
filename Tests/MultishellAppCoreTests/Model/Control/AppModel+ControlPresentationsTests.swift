import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlPresentationsTests {
  @Test func theInfoListsWhatIsUpTopmostFirst() async throws {
    let harness = Harness()
    harness.model.newWorktreeRequest = NewWorktreeRequest(projectID: harness.project.id)
    harness.model.presentedError = PresentedError(title: "Broken", message: "It broke")

    let reply = try #require(await harness.stateSource.ask(.info))

    let presented = try #require(reply.outputFields["presented"] as? [[String: Any]])
    #expect(presented.compactMap { $0["kind"] as? String } == ["alert", "new-worktree"])
    #expect(presented.first?["title"] as? String == "Broken")
  }

  @Test func aDismissTakesDownTheTopmostAsItsCancelAndLeavesTheRest() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.pendingClose = .tab(tab.id)
    harness.model.presentedError = PresentedError(title: "Broken", message: "It broke")

    let first = try #require(await harness.stateSource.ask(.dismissPresentation))
    #expect(first.outputFields["kind"] as? String == "alert")
    #expect(harness.model.presentedError == nil)
    #expect(harness.model.pendingClose != nil)

    let second = try #require(await harness.stateSource.ask(.dismissPresentation))
    #expect(second.outputFields["kind"] as? String == "close-confirmation")
    #expect(harness.model.pendingClose == nil)
    #expect(harness.model.workspace.tab(tab.id) != nil, "cancelled, not confirmed")

    #expect(
      await harness.stateSource.ask(.dismissPresentation) == .refused(.nothingPresented)
    )
  }

  @Test func aDismissClosesTheNewWorktreeSheetAndANameField() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.presentedError = nil
    harness.model.newWorktreeRequest = NewWorktreeRequest(projectID: harness.project.id)
    harness.model.beginRenamingTab(tab.id)

    _ = await harness.stateSource.ask(.dismissPresentation)
    #expect(harness.model.newWorktreeRequest == nil)
    #expect(harness.model.renamingTabID == tab.id)

    _ = await harness.stateSource.ask(.dismissPresentation)
    #expect(harness.model.renamingTabID == nil)
  }
}

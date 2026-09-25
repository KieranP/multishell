import MultishellCore
import MultishellGitKit
import MultishellProcess
import Testing

@testable import MultishellAppCore

/// Everything the model wants from the desktop goes through the port, so a
/// second frontend implements one protocol and the model is untouched.
@Suite @MainActor
struct AppModelPlatformTests {
  @Test func revealingAndCopyingGoThroughThePlatform() {
    let h = Harness()
    h.model.revealInFileBrowser(h.main.path)
    h.model.copyToClipboard("feature")
    #expect(h.platform.revealed == [h.main.path])
    #expect(h.platform.clipboard == ["feature"])
  }

  @Test func closingInAnotherWindowClosesThatWindowNotAPane() {
    let h = Harness()
    h.model.select(h.main)
    h.platform.workspaceWindowIsKey = false

    h.model.closeActivePane()
    h.model.closeActiveTab()

    #expect(h.platform.closedKeyWindows == 2)
    #expect(h.model.liveTerminalCount == 1, "the pane is still there")
  }

  @Test func aCancelledDirectoryPickerAddsNothing() async {
    let h = Harness()
    h.platform.directoryToChoose = nil
    await h.model.chooseProject()
    #expect(h.model.workspace.projects.count == 1)
  }

  @Test func theModelListensForTheAppComingToTheFrontAndCapturesTheLoginShell() async {
    let h = Harness()
    #expect(h.platform.onDidBecomeActive != nil, "the model listens from its init")
    await h.model.refreshLoginEnvironment()
    let environment = h.model.loginEnvironment
    #expect(environment != nil)
    if case .processFallback = environment?.source {
      #expect(h.platform.logged.count == 1, "a shell that could not answer is logged, not shown")
    } else {
      #expect(h.platform.logged.isEmpty)
    }
  }
}

import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelShellTests {
  @Test func theCustomPathFieldShowsOnlyForTheCustomShell() {
    let harness = Harness()
    #expect(!harness.model.usesCustomShell)

    harness.model.setPreferredShell(ShellChoice.customID)
    #expect(harness.model.usesCustomShell)

    harness.model.setPreferredShell(ShellChoice.loginShellID)
    #expect(!harness.model.usesCustomShell)
  }

  @Test func theGlobalShellIsTheLoginShellUntilOneIsChosen() {
    let harness = Harness()
    #expect(harness.model.globalShellID == ShellChoice.loginShellID)

    harness.model.setPreferredShell("/bin/zsh")

    #expect(harness.model.globalShellID == "/bin/zsh")
  }

  @Test func theCustomShellCaptionSaysWhenThePathWillNotRun() {
    let harness = Harness()
    harness.model.setPreferredShell(ShellChoice.customID)
    #expect(harness.model.customShellPathProblem?.hasPrefix("Blank") == true)
    #expect(harness.model.shellDisplayName(ShellChoice.customID).contains("blank"))

    harness.model.setCustomShellPath("/no/such/shell")
    #expect(harness.model.customShellPathProblem?.hasPrefix("Nothing executable") == true)

    harness.model.setCustomShellPath(" /bin/sh ")
    #expect(harness.model.customShellPathProblem == nil)
    #expect(harness.model.shellDisplayName(ShellChoice.customID) == "the custom path /bin/sh")
  }
}

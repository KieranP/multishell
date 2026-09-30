import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelGlobalShellIDTests {
  @Test func theGlobalShellIsTheLoginShellUntilOneIsChosen() {
    let h = Harness()
    #expect(h.model.globalShellID == ShellCatalogue.loginShellID)

    h.model.setPreferredShell("/bin/zsh")

    #expect(h.model.globalShellID == "/bin/zsh")
  }
}

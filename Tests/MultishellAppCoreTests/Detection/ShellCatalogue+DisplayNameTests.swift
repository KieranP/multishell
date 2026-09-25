import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ShellCatalogueDisplayNameTests {
  @Test func theShellNameSaysWhatTheLoginAndCustomChoicesResolveTo() {
    #expect(
      ShellCatalogue.displayName(nil, customPath: "", loginShell: "/bin/zsh")
        == "the login shell (/bin/zsh)")
    #expect(
      ShellCatalogue.displayName("login", customPath: "", loginShell: "/bin/zsh")
        == "the login shell (/bin/zsh)")
    #expect(
      ShellCatalogue.displayName("/bin/bash", customPath: "", loginShell: "/bin/zsh") == "/bin/bash"
    )
    #expect(
      ShellCatalogue.displayName("custom", customPath: " /opt/fish ", loginShell: "/bin/zsh")
        == "the custom path /opt/fish")
    #expect(
      ShellCatalogue.displayName("custom", customPath: "", loginShell: "/bin/zsh")
        == "the custom path, blank, so the login shell")
  }
}

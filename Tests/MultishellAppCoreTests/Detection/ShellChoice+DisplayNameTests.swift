import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ShellChoiceDisplayNameTests {
  @Test func theShellNameSaysWhatTheLoginAndCustomChoicesResolveTo() {
    #expect(
      ShellChoice.displayName(nil, customPath: "", loginShell: "/bin/zsh")
        == "the login shell (/bin/zsh)"
    )
    #expect(
      ShellChoice.displayName("login", customPath: "", loginShell: "/bin/zsh")
        == "the login shell (/bin/zsh)"
    )
    #expect(
      ShellChoice.displayName("/bin/bash", customPath: "", loginShell: "/bin/zsh") == "/bin/bash"
    )
    #expect(
      ShellChoice.displayName("custom", customPath: " /opt/fish ", loginShell: "/bin/zsh")
        == "the custom path /opt/fish"
    )
    #expect(
      ShellChoice.displayName("custom", customPath: "", loginShell: "/bin/zsh")
        == "the custom path, blank, so the login shell"
    )
  }
}

import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ShellChoiceTests {
  @Test func theProjectOverrideWinsAndLoginMeansTheLoginShell() {
    #expect(ShellChoice.effectivePath(global: nil, override: nil) == nil)
    #expect(ShellChoice.effectivePath(global: "/bin/bash", override: nil) == "/bin/bash")
    #expect(
      ShellChoice.effectivePath(global: "/bin/bash", override: "/opt/homebrew/bin/fish")
        == "/opt/homebrew/bin/fish"
    )
    #expect(
      ShellChoice.effectivePath(global: "/bin/bash", override: ShellChoice.loginShellID)
        == nil,
      "a project can step back to $SHELL",
    )
    #expect(ShellChoice.effectivePath(global: "", override: nil) == nil)
  }

  @Test func theCustomIdResolvesToTheTypedPathOrToTheLoginShellWhenBlank() {
    let custom = ShellChoice.customID
    #expect(
      ShellChoice.effectivePath(global: custom, override: nil, customPath: " /opt/nu ")
        == "/opt/nu"
    )
    #expect(ShellChoice.effectivePath(global: custom, override: nil, customPath: "  ") == nil)
    #expect(ShellChoice.effectivePath(global: custom, override: nil) == nil)
    #expect(
      ShellChoice.effectivePath(global: "/bin/bash", override: custom, customPath: "/opt/nu")
        == "/opt/nu",
      "a project can pick the custom path over a global shell",
    )
    #expect(
      ShellChoice.effectivePath(global: custom, override: "/bin/bash", customPath: "/opt/nu")
        == "/bin/bash"
    )
  }

  @Test func theLoginShellFallsBackToZshWhenTheEnvironmentHasNone() {
    #expect(ShellChoice.loginShellPath(environment: ["SHELL": "/bin/bash"]) == "/bin/bash")
    #expect(ShellChoice.loginShellPath(environment: [:]) == "/bin/zsh")
    #expect(ShellChoice.loginShellPath(environment: ["SHELL": ""]) == "/bin/zsh")
  }
}

import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ShellCatalogueTests {
  @Test func theProjectOverrideWinsAndLoginMeansTheLoginShell() {
    #expect(ShellCatalogue.effectivePath(global: nil, override: nil) == nil)
    #expect(ShellCatalogue.effectivePath(global: "/bin/bash", override: nil) == "/bin/bash")
    #expect(
      ShellCatalogue.effectivePath(global: "/bin/bash", override: "/opt/homebrew/bin/fish")
        == "/opt/homebrew/bin/fish")
    #expect(
      ShellCatalogue.effectivePath(global: "/bin/bash", override: ShellCatalogue.loginShellID)
        == nil, "a project can step back to $SHELL")
    #expect(ShellCatalogue.effectivePath(global: "", override: nil) == nil)
  }

  @Test func theCustomIdResolvesToTheTypedPathOrToTheLoginShellWhenBlank() {
    let custom = ShellCatalogue.customID
    #expect(
      ShellCatalogue.effectivePath(global: custom, override: nil, customPath: " /opt/nu ")
        == "/opt/nu")
    #expect(ShellCatalogue.effectivePath(global: custom, override: nil, customPath: "  ") == nil)
    #expect(ShellCatalogue.effectivePath(global: custom, override: nil) == nil)
    #expect(
      ShellCatalogue.effectivePath(global: "/bin/bash", override: custom, customPath: "/opt/nu")
        == "/opt/nu", "a project can pick the custom path over a global shell")
    #expect(
      ShellCatalogue.effectivePath(global: custom, override: "/bin/bash", customPath: "/opt/nu")
        == "/bin/bash")
  }

  @Test func theLoginShellFallsBackToZshWhenTheEnvironmentHasNone() {
    #expect(ShellCatalogue.loginShellPath(environment: ["SHELL": "/bin/bash"]) == "/bin/bash")
    #expect(ShellCatalogue.loginShellPath(environment: [:]) == "/bin/zsh")
    #expect(ShellCatalogue.loginShellPath(environment: ["SHELL": ""]) == "/bin/zsh")
  }

}

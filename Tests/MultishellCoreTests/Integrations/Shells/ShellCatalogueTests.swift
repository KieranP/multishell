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

  @Test func aWorkspaceResolvesAProjectsShellThroughItsOverride() {
    var workspace = Workspace()
    workspace.defaultShell = "/bin/bash"
    let plain = Project(path: URL(fileURLWithPath: "/repos/a"))
    let fish = Project(
      path: URL(fileURLWithPath: "/repos/b"),
      settings: ProjectSettings(defaultShell: "/usr/local/bin/fish"))
    let login = Project(
      path: URL(fileURLWithPath: "/repos/c"),
      settings: ProjectSettings(defaultShell: ShellCatalogue.loginShellID))
    #expect(workspace.defaultShell(for: plain) == "/bin/bash")
    #expect(workspace.defaultShell(for: fish) == "/usr/local/bin/fish")
    #expect(workspace.defaultShell(for: login) == nil)

    workspace.defaultShell = ShellCatalogue.customID
    workspace.customShellPath = "/opt/homebrew/bin/nu"
    #expect(workspace.defaultShell(for: plain) == "/opt/homebrew/bin/nu")
    #expect(workspace.defaultShell(for: fish) == "/usr/local/bin/fish")
  }
}

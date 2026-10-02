import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The hooks commands a person types, run as the built binary under a home
/// the test wrote.
@Suite(.serialized)
struct HelperHookInstallationTests {
  @Test func printingTheHooksGivesTheSnippetWithoutTouchingAnyFile() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let environment = ["HOME": home.path]

    let claude = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "claude", "--print"], environment: environment)
    #expect(claude.succeeded)
    let object =
      try JSONSerialization.jsonObject(with: Data(claude.standardOutput.utf8)) as? [String: Any]
    let hooks = object?["hooks"] as? [String: Any] ?? [:]
    #expect(Set(hooks.keys) == Set(AgentHookCatalogue.claude.events.map(\.name)))
    #expect(AgentHookCatalogue.claude.holdsAnyOfOurHooks(object ?? [:]))

    let copilot = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "copilot", "--print"], environment: environment)
    #expect(copilot.succeeded)
    let file =
      try JSONSerialization.jsonObject(with: Data(copilot.standardOutput.utf8)) as? [String: Any]
    #expect(file?["version"] as? Int == 1)

    let plugin = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "opencode", "--print"], environment: environment)
    #expect(plugin.succeeded && plugin.standardOutput.contains("MultishellPlugin"))
    #expect(try FileManager.default.contentsOfDirectory(atPath: home.path).isEmpty)
  }

  @Test func aTypedHooksCommandRefusesAMisspeltOrMissingAgent() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let environment = ["HOME": home.path]

    let misspelt = try await HelperBinary.run(
      ["install-agent-hooks", "--agnet", "codex"], environment: environment)
    #expect(misspelt.status == 2, "\(misspelt.standardOutput)")
    #expect(misspelt.standardError.contains("--agnet"))

    let missing = try await HelperBinary.run(["remove-agent-hooks"], environment: environment)
    #expect(missing.status == 2)
    #expect(missing.standardError.contains("--agent"))

    let stray = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "codex", "--print", "extra"], environment: environment)
    #expect(stray.status == 2)

    let unknown = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "nonesuch"], environment: environment)
    #expect(unknown.status == 2 && unknown.standardError.contains("no hooks for nonesuch"))
    #expect(try FileManager.default.contentsOfDirectory(atPath: home.path).isEmpty)
  }

  @Test func hooksAreInstalledAndRemovedUnderTheHomeTheHelperIsGiven() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let file = home.appendingPathComponent(".codex/hooks.json")

    let installed = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "codex"], environment: ["HOME": home.path])
    #expect(installed.succeeded, "\(installed.standardError)")
    #expect(AgentHookCatalogue.codex.installation(in: file) != .absent)

    let removed = try await HelperBinary.run(
      ["remove-agent-hooks", "--agent", "codex"], environment: ["HOME": home.path])
    #expect(removed.succeeded, "\(removed.standardError)")
    #expect(AgentHookCatalogue.codex.installation(in: file) == .absent)
  }
}

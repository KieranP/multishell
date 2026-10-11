import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The hooks commands a person types, run as the built binary under a home
/// the test wrote.
@Suite(.serialized)
struct HelperHookInstallationTests {
  @Test func printingTheHooksGivesTheFileAsInstallWritesItWithoutTouchingAnyFile() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let installed = try Scratch.directory("installed-home")
    defer { Scratch.remove(installed) }

    for agent in ["claude", "copilot", "opencode"] {
      let printed = try await HelperBinary.run(
        ["install-agent-hooks", "--agent", agent, "--print"],
        environment: ["HOME": home.path],
      )
      let install = try await HelperBinary.run(
        ["install-agent-hooks", "--agent", agent],
        environment: ["HOME": installed.path],
      )
      let fields = try JSONSerialization.jsonObject(with: Data(install.standardOutput.utf8))
      let file = try #require((fields as? [String: String])?["file"], "\(agent)")

      #expect(printed.succeeded && install.succeeded, "\(agent): \(printed.standardError)")
      #expect(printed.standardOutput == (try String(contentsOfFile: file, encoding: .utf8)))
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: home.path).isEmpty)
  }

  @Test func aTypedHooksCommandRefusesAMisspeltOrMissingAgent() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let environment = ["HOME": home.path]

    let misspelt = try await HelperBinary.run(
      ["install-agent-hooks", "--agnet", "codex"],
      environment: environment,
    )
    #expect(misspelt.status == 2, "\(misspelt.standardOutput)")
    #expect(misspelt.standardError.contains("--agnet"))

    let missing = try await HelperBinary.run(["remove-agent-hooks"], environment: environment)
    #expect(missing.status == 2)
    #expect(missing.standardError.contains("--agent"))

    let stray = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "codex", "--print", "extra"],
      environment: environment,
    )
    #expect(stray.status == 2)

    let unknown = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "nonesuch"],
      environment: environment,
    )
    #expect(unknown.status == 2 && unknown.standardError.contains("no hooks for nonesuch"))
    #expect(try FileManager.default.contentsOfDirectory(atPath: home.path).isEmpty)
  }

  @Test func hooksAreInstalledAndRemovedUnderTheHomeTheHelperIsGiven() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let file = home.appendingPathComponent(".codex/hooks.json")

    let installed = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "codex"],
      environment: ["HOME": home.path],
    )
    #expect(installed.succeeded, "\(installed.standardError)")
    #expect(AgentHookCatalogue.codex.installState(in: file) != .absent)

    let removed = try await HelperBinary.run(
      ["remove-agent-hooks", "--agent", "codex"],
      environment: ["HOME": home.path],
    )
    #expect(removed.succeeded, "\(removed.standardError)")
    #expect(AgentHookCatalogue.codex.installState(in: file) == .absent)
  }

  @Test func installingAndRemovingNameTheAgentAndItsFileAsJSON() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let environment = ["HOME": home.path]

    for command in ["install-agent-hooks", "remove-agent-hooks"] {
      let output = try await HelperBinary.run(
        [command, "--agent", "claude"],
        environment: environment,
      )
      let printed = try JSONSerialization.jsonObject(with: Data(output.standardOutput.utf8))
      let fields = printed as? [String: String]
      #expect(fields?["agent"] == "claude", "\(command): \(output.standardOutput)")
      #expect(fields?["file"]?.hasPrefix(home.path) == true, "\(command)")
    }
  }
}

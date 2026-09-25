import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct AgentDetectionTests {
  @Test func agentsAreFoundOnTheGivenPathOnly() throws {
    let bin = try fakeBin(["claude", "codex"])
    defer { try? FileManager.default.removeItem(at: bin) }

    let detection = AgentDetection(path: "/usr/bin:\(bin.path)")
    #expect(Set(detection.found.keys) == ["claude", "codex"])
    #expect(detection.found["claude"]?.path == bin.appendingPathComponent("claude").path)
    #expect(detection.isInstalled("claude"))
    #expect(!detection.isInstalled("gemini"))
    #expect(AgentDetection(path: "/usr/bin").found.isEmpty, "nothing on a path with no agents")
  }

  @Test func theDropdownListsInstalledAgentsTheStaleChoiceAndCustom() throws {
    let bin = try fakeBin(["codex"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let detection = AgentDetection(path: bin.path)

    let plain = detection.options(selected: nil).map(\.id)
    #expect(plain == ["none", "codex", "custom"])

    let stale = detection.options(selected: "claude")
    #expect(stale.map(\.id) == ["none", "claude", "codex", "custom"], "catalogue order")
    #expect(stale[1].label == "Claude Code (not installed)")
    #expect(!stale[1].isInstalled)

    let unknown = detection.options(selected: "future-agent")
    #expect(unknown.map(\.id).contains("future-agent"), "a newer build's id still shows")
    #expect(detection.isInstalled("custom"))
    #expect(!detection.isInstalled("claude"))
  }
}

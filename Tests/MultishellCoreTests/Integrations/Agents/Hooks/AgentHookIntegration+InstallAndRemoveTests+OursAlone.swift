import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Copilot's own hook file and OpenCode's plugin, both written whole.
extension AgentHookIntegrationInstallAndRemoveTests {
  /// Copilot reads every JSON file in its hooks directory, so ours is a
  /// file of its own: one flat list of hooks per event, and a version.
  @Test func copilotGetsAFileOfItsOwnWrittenWholeAndDeletedToRemoveIt() throws {
    let directory = Scratch.path("hooks")
    defer { Scratch.remove(directory) }
    let file = directory.appendingPathComponent("hooks/multishell.json")
    let copilot = AgentHookCatalogue.copilot

    try copilot.install(into: file, helper: helper)
    let written =
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any] ?? [:]
    #expect(written["version"] as? Int == 1)
    let hooks = try #require(written["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == Set(copilot.events.map(\.name)))
    let stop = try #require(hooks["Stop"] as? [[String: Any]])
    #expect(stop.count == 1, "a hook on its own, not a group of them")
    #expect(AgentHookCatalogue.isOurHook(stop[0]["command"] as? String ?? ""))
    #expect(stop[0]["timeoutSec"] as? Int == 5, "Copilot counts it under its own key")
    #expect(copilot.hasOurHookUnderEveryEvent(in: file))

    try copilot.remove(from: file)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(!copilot.hasOurHookUnderEveryEvent(in: file))
  }

  @Test func aFileWithOurNameButNotOurHooksIsLeftWhereItIs() throws {
    let (directory, file) = try scratchSettingsFile(named: "multishell.json")
    defer { Scratch.remove(directory) }
    try #"{"version":1,"hooks":{}}"#.write(to: file, atomically: true, encoding: .utf8)

    #expect(!AgentHookCatalogue.copilot.hasOurHookUnderEveryEvent(in: file))
    try AgentHookCatalogue.copilot.remove(from: file)
    #expect(FileManager.default.fileExists(atPath: file.path))
  }

  /// OpenCode reports nothing to a hook command, so its plugin calls the helper itself, with the
  /// states spelled as the helper takes them.
  @Test func openCodeGetsAPluginThatCallsTheHelper() throws {
    let directory = Scratch.path("hooks")
    defer { Scratch.remove(directory) }
    let file = directory.appendingPathComponent("plugin/multishell.js")
    let openCode = AgentHookCatalogue.openCode

    try openCode.install(into: file, helper: helper)
    let source = try String(contentsOf: file, encoding: .utf8)
    #expect(
      source.contains("homedir() + \"/Library/Application Support/Multishell/bin/multishell\"")
    )
    #expect(source.contains("\"state\", state, \"--agent\", \"opencode\""))
    for state in [SessionState.running, .attention, .done, .failed] {
      #expect(source.contains("report(\"\(state.rawValue)\""), "no \(state.rawValue)")
    }
    #expect(openCode.hasOurHookUnderEveryEvent(in: file))
    #expect(openCode.hooksObject(helper: helper).isEmpty, "a plugin is not a hooks object")

    try openCode.remove(from: file)
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }
}

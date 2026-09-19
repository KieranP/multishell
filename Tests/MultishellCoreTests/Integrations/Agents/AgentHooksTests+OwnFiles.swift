import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Copilot's own hook file and OpenCode's plugin, both written whole.
extension AgentHooksTests {
  /// Copilot reads every JSON file in its hooks directory, so ours is a
  /// file of its own: one flat list of hooks per event, and a version.
  @Test func copilotGetsAFileOfItsOwnWrittenWholeAndDeletedToRemoveIt() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("hooks/multishell.json")
    let copilot = AgentHooks.copilot

    try copilot.install(into: file, helper: helper)
    let written =
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any] ?? [:]
    #expect(written["version"] as? Int == 1)
    let hooks = try #require(written["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == Set(copilot.events.map(\.name)))
    let stop = try #require(hooks["Stop"] as? [[String: Any]])
    #expect(stop.count == 1, "a hook on its own, not a group of them")
    #expect(AgentHooks.isMultishellHook(stop[0]["command"] as? String ?? ""))
    #expect(stop[0]["timeoutSec"] as? Int == 5, "Copilot counts it under its own key")
    #expect(copilot.isInstalled(in: file))

    try copilot.remove(from: file)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(!copilot.isInstalled(in: file))
  }

  /// The name is ours; the file on disk decides. Removing must not delete
  /// something else that happens to be called that.
  @Test func aFileOfOursThatIsNotOursIsLeftWhereItIs() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("multishell.json")
    try #"{"version":1,"hooks":{}}"#.write(to: file, atomically: true, encoding: .utf8)

    #expect(!AgentHooks.copilot.isInstalled(in: file))
    try AgentHooks.copilot.remove(from: file)
    #expect(FileManager.default.fileExists(atPath: file.path))
  }

  /// OpenCode reports nothing to a hook command, so it is given a plugin
  /// that calls the helper itself, with the states spelled as the helper
  /// takes them.
  @Test func openCodeGetsAPluginThatCallsTheHelper() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("plugin/multishell.js")
    let openCode = AgentHooks.openCode

    try openCode.install(into: file, helper: helper)
    let source = try String(contentsOf: file, encoding: .utf8)
    #expect(
      source.contains("homedir() + \"/Library/Application Support/Multishell/bin/multishell\""))
    #expect(source.contains("\"state\", state, \"--agent\", \"opencode\""))
    for state in [SessionState.running, .attention, .done, .error] {
      #expect(source.contains("report(\"\(state.rawValue)\""), "no \(state.rawValue)")
    }
    #expect(source.contains("session.idle"))
    // A subagent is a child session: told by `parentID` when it is created,
    // followed by its own id after, and never reported as the pane's Done.
    #expect(source.contains("session.created"))
    #expect(source.contains("info.parentID"))
    #expect(source.contains("\"--subagent\", worker.id, \"--subagent-phase\", worker.phase"))
    #expect(source.contains(#"status === "idle""#), "session.idle is deprecated; both end a child")
    #expect(
      source.contains(#"} else if (idle) report("done")"#),
      "the parent's own Done is taken from either spelling too")
    // A child's id outlives its end, so a late event of its own is not read
    // as the parent's, and the oldest are dropped rather than held forever.
    #expect(source.contains("finish(id)"))
    #expect(source.contains("if (!child) return"))
    #expect(source.contains("ended.length > 64"), "the cap is on the list, not on the map")
    #expect(source.contains("ended.indexOf(id)"), "one place per child in it")
    #expect(source.contains(#""--new-turn", "true""#), "a prompt in the parent starts a turn")
    // A permission asked inside a child names the child's session, and is a
    // prompt of that worker's, not a silence.
    #expect(source.contains(#"report("attention", asked(properties), child)"#))
    #expect(source.contains(#"report("running", undefined, child)"#))
    for phase in SubagentReport.Phase.allCases {
      #expect(source.contains("\"\(phase.rawValue)\""), "no \(phase.rawValue)")
    }
    #expect(source.contains("permission.asked"), "the hook of that name is never called")
    #expect(source.contains("permission.replied"), "the one agent that says the answer came")
    #expect(
      !source.contains("\"permission.ask\":"),
      "listening on both would report one prompt twice")
    #expect(openCode.isInstalled(in: file))
    #expect(openCode.entries(helper: helper).isEmpty, "a plugin is not a hooks object")

    try openCode.remove(from: file)
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }
}

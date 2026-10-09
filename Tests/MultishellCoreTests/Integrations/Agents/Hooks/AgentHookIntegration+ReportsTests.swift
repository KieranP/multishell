import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct AgentHookIntegrationReportsTests {
  @Test func claudesStopSaysATurnFollowsWhereItsTranscriptHasANoticeQueued() throws {
    let directory = try Scratch.directory("hooks")
    defer { Scratch.remove(directory) }
    let transcript = directory.appendingPathComponent("session.jsonl")
    try Data(
      (#"{"type":"queue-operation","operation":"enqueue","timestamp":"2026-09-30T10:00:05.000Z","#
        + #""content":"<task-notification><task-id>a1</task-id>"}"#).utf8
    ).write(to: transcript)
    func follows(_ integration: AgentHookIntegration, _ event: String) -> Bool? {
      let payload = AgentHookPayload(
        json: Data(
          #"{"hook_event_name":"\#(event)","transcript_path":"\#(transcript.path)"}"#.utf8
        )
      )!
      return integration.report(for: payload, sessionID: nil, workingDirectory: nil, pid: nil)?
        .turnFollows
    }
    #expect(follows(AgentHookCatalogue.claude, "Stop") == true)
    #expect(follows(AgentHookCatalogue.claude, "PreToolUse") == nil, "only a Stop reads it")
    #expect(follows(AgentHookCatalogue.codex, "Stop") == nil, "Claude's transcript alone")
  }

  @Test func claudesPermissionNotificationForAQuestionIsMarkedAsOne() throws {
    let directory = try Scratch.directory("hooks")
    defer { Scratch.remove(directory) }
    let transcript = directory.appendingPathComponent("session.jsonl")
    func report(
      lastToolCalled tool: String,
      answered: Bool = false,
      by integration: AgentHookIntegration = AgentHookCatalogue.claude,
    ) throws -> SessionStateReport? {
      var lines = [
        #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"\#(tool)"}]}}"#
      ]
      if answered {
        lines.append(
          #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1"}]}}"#
        )
      }
      try Data(lines.joined(separator: "\n").utf8).write(to: transcript)
      let payload = AgentHookPayload(
        json: Data(
          (#"{"hook_event_name":"Notification","message":"Claude needs your permission","#
            + #""notification_type":"permission_prompt","transcript_path":"\#(transcript.path)"}"#)
            .utf8
        )
      )!
      return integration.report(for: payload, sessionID: nil, workingDirectory: nil, pid: nil)
    }
    let question = try report(lastToolCalled: "AskUserQuestion")
    #expect(question?.asksQuestion == true)
    #expect(question?.message == "Claude needs your permission", "an older app's words")
    #expect(try report(lastToolCalled: "Bash")?.asksQuestion == nil)
    #expect(try report(lastToolCalled: "AskUserQuestion", answered: true)?.asksQuestion == nil)
    #expect(
      try report(lastToolCalled: "AskUserQuestion", by: AgentHookCatalogue.copilot)?.asksQuestion
        == nil,
      "Copilot's notifications share the type",
    )
  }

  @Test func aClaudeWorkersToolCallCarriesItsParentAndNameFromBesideTheTranscript() throws {
    let directory = try Scratch.directory("hooks")
    defer { Scratch.remove(directory) }
    let transcript = directory.appendingPathComponent("session.jsonl")
    let subagentsFolder = directory.appendingPathComponent("session/subagents")
    try FileManager.default.createDirectory(at: subagentsFolder, withIntermediateDirectories: true)
    try Data(
      (#"{"agentType":"general-purpose","description":"Efficiency angle","#
        + #""parentAgentId":"a0","spawnDepth":2}"#).utf8
    ).write(to: subagentsFolder.appendingPathComponent("agent-a1.meta.json"))
    func worker(
      _ event: String,
      id: String = "a1",
      by integration: AgentHookIntegration = AgentHookCatalogue.claude,
    ) -> WorkerReport? {
      let payload = AgentHookPayload(
        json: Data(
          (#"{"hook_event_name":"\#(event)","agent_id":"\#(id)","agent_type":"general-purpose","#
            + #""transcript_path":"\#(transcript.path)"}"#).utf8
        )
      )!
      return integration.report(for: payload, sessionID: nil, workingDirectory: nil, pid: nil)?
        .worker
    }
    #expect(
      worker("PreToolUse")
        == WorkerReport(
          id: "a1",
          phase: .working,
          type: "general-purpose",
          parentID: "a0",
          description: "Efficiency angle",
        )
    )
    #expect(worker("SubagentStop")?.parentID == nil, "an end is taken off whatever it was under")
    #expect(worker("PreToolUse", id: "a2")?.description == nil, "not yet written")
    #expect(worker("SubagentStart")?.phase == .working, "a start once its file is written resumes")
    #expect(worker("SubagentStart", id: "a2")?.phase == .started)
    #expect(worker("PreToolUse", by: AgentHookCatalogue.codex)?.parentID == nil)
  }

  @Test func aClaudeWorkerStillListedAtItsOwnStopIsPausedAndTheStopSaysWhatIsOut() {
    func stop(
      out tasks: [(id: String, type: String)],
      by integration: AgentHookIntegration = AgentHookCatalogue.claude,
    ) -> SessionStateReport? {
      let listed = tasks.map { #"{"id":"\#($0.id)","type":"\#($0.type)","status":"running"}"# }
      let payload = AgentHookPayload(
        json: Data(
          (#"{"hook_event_name":"SubagentStop","agent_id":"a0","agent_type":"general-purpose","#
            + #""background_tasks":[\#(listed.joined(separator: ","))]}"#).utf8
        )
      )!
      return integration.report(for: payload, sessionID: nil, workingDirectory: nil, pid: nil)
    }
    let paused = stop(out: [("a0", "subagent"), ("b1", "shell")])
    #expect(
      paused?.worker
        == WorkerReport(id: "a0", phase: .working, type: "general-purpose", isPaused: true)
    )
    #expect(
      paused?.workersOut == [
        WorkerReport(id: "a0", phase: .working, type: "subagent"),
        WorkerReport(id: "b1", phase: .working, isBackgroundShell: true),
      ]
    )
    #expect(stop(out: [("a1", "subagent")])?.worker?.phase == .ended)
    #expect(
      stop(out: [("a0", "monitor")])?.worker?.phase == .ended,
      "a watcher is not the worker",
    )
    #expect(stop(out: [])?.workersOut == [])
    #expect(
      stop(out: [("a0", "subagent")], by: AgentHookCatalogue.codex)?.worker?.phase == .ended
    )
  }

  @Test func aBackgroundClaudeWorkerItsOwnStopLeavesOutHasFailed() throws {
    let directory = try Scratch.directory("hooks")
    defer { Scratch.remove(directory) }
    let transcript = directory.appendingPathComponent("session.jsonl")
    let subagentsFolder = directory.appendingPathComponent("session/subagents")
    try FileManager.default.createDirectory(at: subagentsFolder, withIntermediateDirectories: true)
    try Data(#"{"description":"Sleep","requestShape":"background"}"#.utf8)
      .write(to: subagentsFolder.appendingPathComponent("agent-a0.meta.json"))
    try Data(#"{"description":"Look","requestShape":"foreground"}"#.utf8)
      .write(to: subagentsFolder.appendingPathComponent("agent-a1.meta.json"))
    func end(of id: String, listing: String? = "[]") -> WorkerReport? {
      let list = listing.map { #","background_tasks":\#($0)"# } ?? ""
      let payload = AgentHookPayload(
        json: Data(
          (#"{"hook_event_name":"SubagentStop","agent_id":"\#(id)","#
            + #""transcript_path":"\#(transcript.path)"\#(list)}"#).utf8
        )
      )!
      return AgentHookCatalogue.claude.report(
        for: payload,
        sessionID: nil,
        workingDirectory: nil,
        pid: nil,
      )?.worker
    }
    #expect(end(of: "a0") == WorkerReport(id: "a0", phase: .ended, hasFailed: true))
    #expect(end(of: "a1")?.hasFailed == nil, "a foreground worker is never listed")
    #expect(end(of: "a0", listing: nil)?.hasFailed == nil, "no list says nothing")
  }

  @Test func claudesToolResultNamesTheWorkerOrShellItLaunchedInTheBackground() {
    func launched(
      _ toolName: String,
      input: String,
      response: String,
      inside workerID: String? = "a0",
      by integration: AgentHookIntegration = AgentHookCatalogue.claude,
    ) -> WorkerReport? {
      let worker = workerID.map { #""agent_id":"\#($0)","agent_type":"general-purpose","# } ?? ""
      let payload = AgentHookPayload(
        json: Data(
          (#"{"hook_event_name":"PostToolUse",\#(worker)"tool_name":"\#(toolName)","#
            + #""tool_input":\#(input),"tool_response":\#(response)}"#).utf8
        )
      )!
      return integration.report(for: payload, sessionID: nil, workingDirectory: nil, pid: nil)?
        .launched
    }
    let agentInput = #"{"subagent_type":"Explore","name":"scout","description":"Map the hooks"}"#
    let asyncLaunch =
      #"{"isAsync":true,"status":"async_launched","agentId":"a1","description":"Map the hooks"}"#
    #expect(
      launched("Agent", input: agentInput, response: asyncLaunch)
        == WorkerReport(
          id: "a1",
          phase: .started,
          type: "Explore",
          parentID: "a0",
          name: "scout",
          description: "Map the hooks",
        )
    )
    #expect(
      launched("Agent", input: agentInput, response: asyncLaunch, inside: nil)?.parentID == nil
    )
    #expect(
      launched("Bash", input: #"{"command":"sleep 30"}"#, response: #"{"backgroundTaskId":"b1"}"#)
        == WorkerReport(id: "b1", phase: .started, isBackgroundShell: true, parentID: "a0")
    )
    #expect(
      launched("Agent", input: agentInput, response: #"{"status":"completed","agentId":"a1"}"#)
        == nil,
      "a foreground worker has ended by its result",
    )
    #expect(
      launched("Agent", input: agentInput, response: asyncLaunch, by: AgentHookCatalogue.codex)
        == nil
    )
  }

  @Test func claudesTaskStopResultNamesTheTaskItKilled() {
    func killed(
      _ response: String,
      by integration: AgentHookIntegration = AgentHookCatalogue.claude,
    ) -> String? {
      let payload = AgentHookPayload(
        json: Data(
          (#"{"hook_event_name":"PostToolUse","tool_name":"TaskStop","#
            + #""tool_input":{"task_id":"a0"},"tool_response":\#(response)}"#).utf8
        )
      )!
      return integration.report(for: payload, sessionID: nil, workingDirectory: nil, pid: nil)?
        .killedTaskID
    }
    let stopped =
      #"{"message":"Successfully stopped task: a0 (x)","task_id":"a0","task_type":"local_agent"}"#
    #expect(killed(stopped) == "a0")
    #expect(killed(#"{"message":"not running"}"#) == nil, "a result naming no task stopped none")
    #expect(killed(stopped, by: AgentHookCatalogue.codex) == nil)
  }

  @Test func anOversizedNameBesideTheTranscriptStillLeavesAReportThatFits() throws {
    let directory = try Scratch.directory("hooks")
    defer { Scratch.remove(directory) }
    let transcript = directory.appendingPathComponent("session.jsonl")
    let subagentsFolder = directory.appendingPathComponent("session/subagents")
    try FileManager.default.createDirectory(at: subagentsFolder, withIntermediateDirectories: true)
    let description = String(repeating: "x", count: 60_000)
    try Data(#"{"description":"\#(description)"}"#.utf8)
      .write(to: subagentsFolder.appendingPathComponent("agent-a1.meta.json"))
    let payload = AgentHookPayload(
      json: Data(
        (#"{"hook_event_name":"PreToolUse","agent_id":"a1","#
          + #""transcript_path":"\#(transcript.path)"}"#).utf8
      )
    )!
    let report = try #require(
      AgentHookCatalogue.claude.report(
        for: payload,
        sessionID: nil,
        workingDirectory: nil,
        pid: nil,
      )
    )
    #expect(try report.encodedLine().utf8.count < 1_000)
  }

  @Test func anAgentThatWakesForItsWorkersSaysSoAtItsStop() {
    func resumes(_ integration: AgentHookIntegration, _ event: String) -> Bool? {
      let payload = AgentHookPayload(eventName: event)
      return integration.report(for: payload, sessionID: nil, workingDirectory: nil, pid: nil)?
        .resumesAfterWorkers
    }
    #expect(resumes(AgentHookCatalogue.claude, "Stop") == true)
    #expect(resumes(AgentHookCatalogue.copilot, "Stop") == true, "its runtime wakes it")
    #expect(resumes(AgentHookCatalogue.codex, "Stop") == nil, "a child's answer starts no turn")
  }

  @Test func claudesStopListsWhatIsOutShellsIncluded() {
    func stop(_ tasks: String) -> (report: SessionStateReport?, walked: Bool) {
      let payload = AgentHookPayload(
        json: Data(#"{"hook_event_name":"Stop","background_tasks":\#(tasks)}"#.utf8)
      )!
      var walked = false
      let report = AgentHookCatalogue.claude.report(
        for: payload,
        sessionID: nil,
        workingDirectory: nil,
        pid: 7,
        findBackgroundShells: { _ in
          walked = true
          return [500]
        },
      )
      return (report, walked)
    }
    let subagent =
      #"{"id":"a1","type":"subagent","status":"running","description":"d","agent_type":"Explore"}"#
    let monitor = #"{"id":"m1","type":"monitor","status":"running","description":"d"}"#
    let shell = #"{"id":"b1","type":"shell","status":"running","description":"d","command":"x"}"#
    let dream = #"{"id":"d1","type":"dream","status":"running","description":"dreaming"}"#
    let cloud = #"{"id":"r1","type":"cloud session","status":"running","description":"d"}"#
    let scan = #"{"id":"s1","type":"auto-mode scan","status":"running","description":"d"}"#

    let quiet = stop("[]")
    #expect(quiet.report?.workersOut == [], "nothing out is said, not left unsaid")
    #expect(!quiet.walked)

    let busy = stop("[\(subagent),\(dream),\(monitor),\(scan),\(cloud),\(shell)]")
    #expect(
      busy.report?.workersOut == [
        WorkerReport(id: "a1", phase: .working, type: "Explore"),
        WorkerReport(id: "r1", phase: .working, type: "cloud session"),
        WorkerReport(id: "b1", phase: .working, isBackgroundShell: true),
      ],
      "a watcher that never ends and housekeeping ending unannounced hold nothing",
    )
    #expect(!busy.walked, "the list names the shell")
    #expect(busy.report?.backgroundShells == nil)
  }
}

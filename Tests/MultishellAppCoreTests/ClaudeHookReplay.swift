import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

/// Feeds captured payloads through Claude's hook integration and the session
/// states, as the helper and the app would, noting what each list named.
struct ClaudeHookReplay {
  let directory: URL
  let claude = AgentHookCatalogue.integration("claude")!
  var states = SessionStates()
  var lastListedIDs: Set<String> = []
  var launcherByWorkerID: [String: String] = [:]
  var startedWorkerIDs: Set<String> = []

  init() throws {
    directory = try Scratch.directory("claude-capture")
    try FileManager.default.createDirectory(
      at: directory.appendingPathComponent("session/subagents"),
      withIntermediateDirectories: true)
  }

  /// Claude writes a worker's metadata just after its first start.
  mutating func feed(_ line: String, for key: SessionStates.Key) throws {
    let transcript = directory.appendingPathComponent("session.jsonl").path
    let json = line.replacingOccurrences(of: "TRANSCRIPT", with: transcript)
    let payload = try #require(AgentHookPayload(json: Data(json.utf8)))
    let object = try #require(
      try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    if let report = claude.report(for: payload, sessionID: nil, workingDirectory: nil, pid: nil) {
      if let launched = report.launched, let launcher = object["agent_id"] as? String {
        launcherByWorkerID[launched.id] = launcher
      }
      if let out = report.workersOut { lastListedIDs = Set(out.map(\.id)) }
      states.apply(report, pid: nil, for: key, isSeen: false)
    }
    let id = object["agent_id"] as? String
    if object["hook_event_name"] as? String == "SubagentStart", let id,
      startedWorkerIDs.insert(id).inserted, let metadata = ClaudeHookCapture.workerMetadata[id]
    {
      try Data(metadata.utf8).write(
        to: directory.appendingPathComponent("session/subagents/agent-\(id).meta.json"))
    }
  }
}

import Foundation
import Testing

@testable import MultishellCore

@Suite
struct SessionStateReportLegacyWorkerCountTests {
  /// The field a worker rides on, both directions: an older helper and an older
  /// app each have to meet a newer one over the shared helper link.
  @Test func aSubagentSurvivesTheWireBothWays() throws {
    let worker = WorkerReport(id: "agent_1", phase: .working, type: "Explore")
    let sent = SessionStateReport(state: .running, agentID: "claude", worker: worker)
    let line = try sent.encodedLine()
    #expect(line.contains(#""subagent":{"id":"agent_1","phase":"working","type":"Explore"}"#))
    #expect(try #require(SessionStateReport.parse(line)) == sent)
    #expect(SessionStateReport.parse(line)?.workerChange == worker)

    let quiet = try SessionStateReport(state: .done).encodedLine()
    #expect(!quiet.contains("subagent"), "a report that is not about them says nothing")
    #expect(SessionStateReport.parse(quiet)?.workerChange == nil)

    let old = #"{"v":1,"state":"done","agent":"claude"}"#
    #expect(SessionStateReport.parse(old)?.workerChange == nil, "absent reads as no change")
    // What an older helper writes: a count, read as an unnamed worker.
    let counted = #"{"v":1,"state":"running","subagents":1,"somethingLater":true}"#
    #expect(
      SessionStateReport.parse(counted)?.workerChange
        == WorkerReport(id: WorkerReport.anonymousID, phase: .started)
    )
    let uncounted = #"{"v":1,"state":"running","subagents":-1}"#
    #expect(
      SessionStateReport.parse(uncounted)?.workerChange
        == WorkerReport(id: WorkerReport.anonymousID, phase: .ended)
    )
  }

  /// The other direction: a newer helper writing to an older app, which reads
  /// the count and ignores the object. A tool call carries no count.
  @Test func aNewHelpersWorkerIsCountedForAnOlderApp() throws {
    func line(_ phase: WorkerReport.Phase) throws -> String {
      try SessionStateReport(
        state: .running,
        worker: WorkerReport(id: "agent_1", phase: phase, type: "Explore"),
      ).encodedLine()
    }
    #expect(try line(.started).contains(#""subagents":1"#))
    #expect(try line(.ended).contains(#""subagents":-1"#))
    #expect(try !line(.working).contains(#""subagents""#))

    let start = try line(.started)
    #expect(
      SessionStateReport.parse(start)?.workerChange
        == WorkerReport(id: "agent_1", phase: .started, type: "Explore"),
      "a new app still reads the named worker, not the count",
    )
  }
}

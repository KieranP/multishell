import Testing

@testable import MultishellCore

/// What the generated plugin says, read as text. Apart from
/// `OpenCodePluginTests`, which runs it and so needs a node.
@Suite
struct OpenCodePluginSourceTests {
  @Test func aWorkerIsReportedByItsSessionIdAndTheEndedIdsAreCapped() {
    let source = OpenCodePlugin.source(helper: "$HOME/bin/multishell")
    #expect(source.contains("\"--subagent\", worker.id, \"--subagent-phase\", worker.phase"))
    #expect(source.contains("ended.length > 64"), "the cap is on the list, not on the map")
  }

  @Test func aPermissionIsHeardByItsReplyAndNotByAnAskHookOpenCodeNeverCalls() {
    let source = OpenCodePlugin.source(helper: "$HOME/bin/multishell")
    #expect(source.contains("permission.replied"), "the one agent that says the answer came")
    #expect(
      !source.contains("\"permission.ask\":"),
      "listening on both would report one prompt twice")
  }
}

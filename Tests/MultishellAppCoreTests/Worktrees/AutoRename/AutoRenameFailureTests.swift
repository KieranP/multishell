import Testing

@testable import MultishellAppCore

@Suite
struct AutoRenameFailureTests {
  private static func shown(_ said: String) -> String {
    AutoRenameFailure.agentFailed(agent: "Codex", status: 1, said: said).message
  }

  @Test func aTailStartingAtALineKeepsThatLine() {
    let error = "Error: quota exceeded for model X"
    let said =
      String(repeating: "b", count: 99) + "\n" + error + "\n"
      + String(repeating: "t", count: 300 - error.count - 1)
    #expect(Self.shown(said).contains(error))
  }

  @Test func theFailureShownIsTheEndOfWhatTheAgentSaid() {
    let preamble = (1...20).map { "banner line \($0) with workdir and model" }.joined(
      separator: "\n"
    )

    let failure = Self.shown(preamble + "\nError: not logged in")

    #expect(failure.contains("not logged in"))
    #expect(!failure.contains("banner line 1 "), "the start of a long preamble is cut")
  }
}

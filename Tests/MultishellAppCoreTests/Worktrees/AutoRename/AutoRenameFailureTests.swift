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
}

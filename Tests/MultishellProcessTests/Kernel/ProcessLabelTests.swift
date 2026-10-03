import Testing

@testable import MultishellProcess

@Suite
struct ProcessLabelTests {
  @Test func anInterpreterIsNamedWithTheScriptItRunsPastItsFlags() {
    let label = ProcessLabel.of(
      name: "node", arguments: ["node", "--no-warnings", "/opt/homebrew/bin/gemini", "chat"])
    #expect(label == "node gemini")
  }

  @Test func aProgramOrAnUnreadableInterpreterKeepsItsOwnName() {
    #expect(ProcessLabel.of(name: "claude", arguments: ["claude", "--resume"]) == "claude")
    #expect(ProcessLabel.of(name: "node", arguments: nil) == "node")
    #expect(ProcessLabel.of(name: "node", arguments: ["node"]) == "node")
  }

  @Test func aProgramsArgumentsAreNeverRead() {
    var reads = 0
    func readArguments() -> [String]? {
      reads += 1
      return ["claude", "--resume"]
    }

    _ = ProcessLabel.of(name: "claude", arguments: readArguments())
    #expect(reads == 0)
    _ = ProcessLabel.of(name: "node", arguments: readArguments())
    #expect(reads == 1)
  }
}

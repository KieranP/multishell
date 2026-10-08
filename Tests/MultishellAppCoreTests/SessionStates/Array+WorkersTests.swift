import Testing

@testable import MultishellAppCore

@Suite
struct ArrayWorkersTests {
  @Test func theCountNamesSubagentsAndBackgroundShellsApart() {
    let out = [
      Worker(id: "a", type: "Explore"),
      Worker(id: "shell:500", type: nil, pid: 500),
      Worker(id: "shell:501", type: nil, pid: 501),
    ]
    #expect(out.countText == "1 subagent, 2 background shells")
    #expect([out[1]].countText == "1 background shell")
  }

  @Test func aFailedWorkerIsCountedApartAndAloneTurnsTheChipFailed() {
    var failed = Worker(id: "b", type: "Explore")
    failed.hasFailed = true
    let out = [Worker(id: "a", type: "Explore"), failed]
    #expect(out.countText == "1 subagent, 1 failed")
    #expect(out.chipCount == 1)
    #expect(out.chipState == .running)
    #expect([failed].chipCount == 1)
    #expect([failed].chipState == .failed)
  }
}

import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct DebugGitRunLogTests {
  @Test func theLogKeepsTheNewestRunsUpToItsCapacityOldestFirst() {
    var log = DebugGitRunLog()

    let commands = (0..<DebugGitRunLog.capacity).map { "status \($0)" }
    log.append(commands.map { .sample($0) }, inSample: 0)
    log.append([.sample("fetch")], inSample: 1)

    #expect(log.entries.count == DebugGitRunLog.capacity)
    #expect(log.entries.first?.run.command == "status 1", "only the oldest went")
    #expect(log.entries.last?.run.command == "fetch")
    #expect(log.entries.last?.sample == 1)
  }
}

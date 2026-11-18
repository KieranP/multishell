import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelDebugThreadsTests {
  private func sample(
    _ sequence: Int,
    _ byThread: [DebugThreadKey: DebugThreadTally],
  ) -> DebugSample {
    var sample = DebugSample.sample(sequence: sequence)
    sample.threadCPU = DebugThreadCPU(mainPercent: 0, terminalsPercent: 0, byThread: byThread)
    return sample
  }

  private func groups(of harness: Harness) -> [DebugThreadGroupRow] {
    harness.model.debugThreadGroups(for: .oneMinute, sortedBy: DebugThreadColumn.defaultSort)
  }

  @Test func threadsAddUpOverTheRangeUnderTheirGroupsTheMostCPUFirst() throws {
    let harness = Harness()
    let main = DebugThreadKey(group: .main, name: "")
    let renderer = DebugThreadKey(group: .terminals, name: "renderer")
    let ioThread = DebugThreadKey(group: .terminals, name: "io")
    harness.model.debugHistory = .of([
      sample(
        0,
        [
          main: .init(threadCount: 1, cpuTime: .milliseconds(100)),
          renderer: .init(threadCount: 2, cpuTime: .milliseconds(300)),
        ],
      ),
      sample(
        1,
        [
          main: .init(threadCount: 1, cpuTime: .milliseconds(100)),
          ioThread: .init(threadCount: 1, cpuTime: .milliseconds(100)),
        ],
      ),
    ])

    let groups = groups(of: harness)

    #expect(groups.map(\.title) == ["Terminals", "Main thread"])
    let terminals = try #require(groups.first)
    #expect(terminals.threads.map(\.title) == ["renderer", "io"])
    #expect(terminals.threadCountText == "2", "no one sample held more than two")
    #expect(terminals.meanPercentText == "20%")
  }

  @Test func everyGroupButTheMainThreadOpens() throws {
    let harness = Harness()
    harness.model.debugHistory = .of([
      sample(
        0,
        [
          DebugThreadKey(group: .main, name: ""): .init(threadCount: 1, cpuTime: .milliseconds(1)),
          DebugThreadKey(group: .other, name: ""): .init(
            threadCount: 9,
            cpuTime: .milliseconds(2),
          ),
        ],
      )
    ])

    let groups = groups(of: harness)

    #expect(groups.map(\.title) == ["Other threads", "Main thread"])
    #expect(groups.first?.threads.map(\.title) == ["Unnamed"])
    #expect(groups.first?.disclosure(isExpanded: false) == .collapsed)
    #expect(groups.last?.disclosure(isExpanded: true) == .notExpandable)
  }

  @Test func theGroupsAndTheirThreadsFollowTheSortAskedFor() throws {
    let harness = Harness()
    harness.model.debugHistory = .of([
      sample(
        0,
        [
          DebugThreadKey(group: .main, name: ""): .init(threadCount: 1, cpuTime: .milliseconds(9)),
          DebugThreadKey(group: .other, name: "a"): .init(
            threadCount: 1,
            cpuTime: .milliseconds(1),
          ),
          DebugThreadKey(group: .other, name: "b"): .init(
            threadCount: 1,
            cpuTime: .milliseconds(2),
          ),
        ],
      )
    ])

    let groups = harness.model.debugThreadGroups(
      for: .oneMinute,
      sortedBy: DebugTableSort(column: .cpuTime, isAscending: true),
    )

    #expect(groups.map(\.title) == ["Other threads", "Main thread"])
    #expect(groups.first?.threads.map(\.title) == ["a", "b"])
  }
}

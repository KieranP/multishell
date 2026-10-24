import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite @MainActor
struct OneShotRunnerTests {
  @Test func aStoppedRunIsNoLongerTheWorktreesOnceAnotherStarts() {
    let runner = OneShotRunner()
    let stopped = runner.stopper(for: "/w/feature")
    runner.stop(["/w/feature"])
    let current = runner.stopper(for: "/w/feature")

    #expect(stopped.isStopRequested)
    #expect(!runner.finish("/w/feature", stopper: stopped))
    #expect(runner.finish("/w/feature", stopper: current))
    #expect(!runner.finish("/w/feature", stopper: current), "finished once")
  }

  @Test func stoppingEveryRunStopsEachWorktreesRun() {
    let runner = OneShotRunner()
    let first = runner.stopper(for: "/w/a")
    let second = runner.stopper(for: "/w/b")

    runner.stopAll()

    #expect(first.isStopRequested && second.isStopRequested)
  }
}

import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite @MainActor
struct OneShotRunnerTests {
  @Test func aStoppedRunIsNoLongerTheWorktreesOnceAnotherStarts() {
    let runner = OneShotRunner()
    let stopped = runner.beginRun(for: "/w/feature")
    runner.stop(["/w/feature"])
    let current = runner.beginRun(for: "/w/feature")

    #expect(stopped.isStopRequested)
    #expect(!runner.endRun("/w/feature", stopper: stopped))
    #expect(runner.endRun("/w/feature", stopper: current))
    #expect(!runner.endRun("/w/feature", stopper: current), "finished once")
  }

  @Test func stoppingEveryRunStopsEachWorktreesRun() {
    let runner = OneShotRunner()
    let first = runner.beginRun(for: "/w/a")
    let second = runner.beginRun(for: "/w/b")

    runner.stopAll()

    #expect(first.isStopRequested && second.isStopRequested)
  }
}

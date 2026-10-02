import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct TaskValueWithinTests {
  @Test func aTaskThatEndsInTimeGivesItsValue() async {
    let task = Task<Int, Never> { 42 }
    #expect(await task.value(within: .seconds(30)) == 42)
  }

  @Test func aTaskStillRunningAtTheLimitGivesNilAndIsNotCancelled() async {
    let released = Flag()
    let task = Task<Bool, Never> {
      while !released.raised, !Task.isCancelled {
        try? await Task<Never, Never>.sleep(for: .milliseconds(10))
      }
      return Task.isCancelled
    }
    #expect(await task.value(within: .milliseconds(50)) == nil)
    released.raise()
    #expect(await task.value == false)
  }
}

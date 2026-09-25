import MultishellProcess
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension PresentedErrorTests {
  @Test func aStoppedOrTimedOutHookIsTitledForWhatEndedIt() {
    let timedOut = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "installing",
      stop: .timedOut(after: .seconds(1)))
    let presented = PresentedError(HookFailure(stage: .postCreate, underlying: timedOut))
    #expect(presented.title == "Worktree created, but its hook did not finish")
    #expect(presented.message == "installing\n\nStopped after 1 second, the hook timeout.")

    let stopped = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "", stop: .byUser)
    let byUser = PresentedError(HookFailure(stage: .preCreate, underlying: stopped))
    #expect(byUser.title == "Worktree not created: its pre-create hook was stopped")
    #expect(byUser.message == "Stopped by you and printed nothing.")
  }
}

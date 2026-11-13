import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelErrorReportingTests {
  private func retryable(counting runs: @escaping @MainActor () -> Void) -> PresentedError {
    var error = PresentedError(title: "Not deleted", message: "")
    error.retry = .init(label: "Delete Anyway") { runs() }
    return error
  }

  @Test func anErrorRaisedWhileSettingsIsKeyIsShownThereUntilItCloses() {
    let harness = Harness()
    harness.platform.isWorkspaceWindowKey = false
    harness.platform.isSettingsWindowKey = true

    harness.model.presentedError = PresentedError(title: "Not exported", message: "")

    #expect(harness.model.presentedPlainError(in: .settings) != nil)
    #expect(harness.model.presentedPlainError(in: .workspace) == nil)
    harness.model.noteSettingsWindowClosed()
    #expect(harness.model.presentedPlainError(in: .workspace) != nil)
  }

  @Test func anErrorRaisedUnderASheetOnTheWorkspaceWindowIsShownThere() {
    let harness = Harness()
    harness.platform.isWorkspaceWindowKey = false

    harness.model.presentedError = PresentedError(title: "Worktree not created", message: "")

    #expect(harness.model.presentedPlainError(in: .workspace) != nil)
  }

  @Test func aRetryableErrorGoesToTheDestructiveAlertAndAPlainOneToTheDismiss() {
    let harness = Harness()
    harness.model.presentedError = nil
    #expect(
      harness.model.presentedRetryableError(in: .workspace) == nil
        && harness.model.presentedPlainError(in: .workspace) == nil
    )

    harness.model.presentedError = retryable(counting: {})
    #expect(
      harness.model.presentedRetryableError(in: .workspace) != nil
        && harness.model.presentedPlainError(in: .workspace) == nil
    )

    harness.model.presentedError = PresentedError(title: "Failed", message: "")
    #expect(
      harness.model.presentedRetryableError(in: .workspace) == nil
        && harness.model.presentedPlainError(in: .workspace) != nil
    )
  }

  @Test func answeringWithTheRetryTakesTheAlertDownAndRunsItOnce() async {
    let harness = Harness()
    var runs = 0
    let error = retryable { runs += 1 }
    harness.model.presentedError = error

    await harness.model.answerPresentedError(error, retrying: true)?.value

    #expect(harness.model.presentedError == nil)
    #expect(runs == 1)
  }

  @Test func dismissingTakesTheAlertDownAndRunsNothing() {
    let harness = Harness()
    var runs = 0
    let error = retryable { runs += 1 }
    harness.model.presentedError = error

    #expect(harness.model.answerPresentedError(error, retrying: false) == nil)
    #expect(harness.model.presentedError == nil)
    #expect(runs == 0)
  }
}

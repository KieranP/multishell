import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelErrorReportingTests {
  private func retryable(counting runs: @escaping @MainActor () -> Void) -> PresentedError {
    var error = PresentedError(title: "Not deleted", message: "")
    error.retry = .init(label: "Delete Anyway") { runs() }
    return error
  }

  @Test func onlyAnErrorWithAStrongerFormIsRetryable() {
    #expect(!PresentedError(title: "Failed", message: "").isRetryable)
    #expect(retryable(counting: {}).isRetryable)
  }

  @Test func aRetryableErrorGoesToTheDestructiveAlertAndAPlainOneToTheDismiss() {
    let harness = Harness()
    harness.model.presentedError = nil
    #expect(
      harness.model.presentedRetryableError == nil && harness.model.presentedPlainError == nil)

    harness.model.presentedError = retryable(counting: {})
    #expect(
      harness.model.presentedRetryableError != nil && harness.model.presentedPlainError == nil)

    harness.model.presentedError = PresentedError(title: "Failed", message: "")
    #expect(
      harness.model.presentedRetryableError == nil && harness.model.presentedPlainError != nil)
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

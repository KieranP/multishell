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

  @Test func answeringWithTheRetryTakesTheAlertDownAndRunsItOnce() async {
    let h = Harness()
    var runs = 0
    let error = retryable { runs += 1 }
    h.model.presentedError = error

    await h.model.answerPresentedError(error, retrying: true)?.value

    #expect(h.model.presentedError == nil)
    #expect(runs == 1)
  }

  @Test func dismissingTakesTheAlertDownAndRunsNothing() {
    let h = Harness()
    var runs = 0
    let error = retryable { runs += 1 }
    h.model.presentedError = error

    #expect(h.model.answerPresentedError(error, retrying: false) == nil)
    #expect(h.model.presentedError == nil)
    #expect(runs == 0)
  }
}

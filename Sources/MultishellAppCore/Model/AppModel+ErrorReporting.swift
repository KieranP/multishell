extension AppModel {
  func present(_ error: any Error) {
    presentedError = PresentedError(error)
  }

  /// An error with a stronger form to retry, asked as a destructive alert.
  public var presentedRetryableError: PresentedError? {
    presentedError.flatMap { $0.isRetryable ? $0 : nil }
  }

  /// An error with nothing to retry, which takes the plain dismiss.
  public var presentedPlainError: PresentedError? {
    presentedError.flatMap { $0.isRetryable ? nil : $0 }
  }

  /// The alert's answer. The task is the retry, when one was chosen.
  @discardableResult
  public func answerPresentedError(
    _ error: PresentedError, retrying: Bool
  ) -> Task<Void, Never>? {
    presentedError = nil
    guard retrying, let retry = error.retry else { return nil }
    return Task { await retry.action() }
  }

  func presentingFailure(_ work: () throws -> Void) {
    do {
      try work()
    } catch {
      present(error)
    }
  }
}

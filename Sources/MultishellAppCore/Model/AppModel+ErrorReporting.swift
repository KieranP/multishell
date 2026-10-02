extension AppModel {
  func present(_ error: any Error) {
    presentedError = PresentedError(error)
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

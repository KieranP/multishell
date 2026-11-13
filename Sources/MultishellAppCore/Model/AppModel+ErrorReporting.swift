extension AppModel {
  /// An error with a stronger form to retry, asked as a destructive alert.
  public func presentedRetryableError(in window: DialogWindow) -> PresentedError? {
    presentedError(in: window).flatMap { $0.isRetryable ? $0 : nil }
  }

  /// An error with nothing to retry, which takes the plain dismiss.
  public func presentedPlainError(in window: DialogWindow) -> PresentedError? {
    presentedError(in: window).flatMap { $0.isRetryable ? nil : $0 }
  }

  /// One left for a closed Settings window would be shown nowhere.
  public func noteSettingsWindowClosed() {
    returnSettingsToAllProjects()
    presentedErrorWindow = .workspace
  }

  private func presentedError(in window: DialogWindow) -> PresentedError? {
    presentedErrorWindow == window ? presentedError : nil
  }

  func present(_ error: any Error) {
    presentedError = PresentedError(error)
  }

  /// The alert's answer. The task is the retry, when one was chosen.
  @discardableResult
  public func answerPresentedError(
    _ error: PresentedError,
    retrying: Bool,
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

@testable import MultishellAppCore

extension BaseUpdateAttempt {
  /// The run, where the update ran.
  var run: BaseUpdateRun? {
    guard case .ran(let run) = self else { return nil }
    return run
  }
}

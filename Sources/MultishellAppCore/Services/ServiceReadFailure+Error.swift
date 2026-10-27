import MultishellServices

extension ServiceReadFailure {
  /// Whatever a read threw, as the failure it stands for.
  init(_ error: any Error) {
    self = error as? ServiceReadFailure ?? .failed(String(describing: error))
  }
}

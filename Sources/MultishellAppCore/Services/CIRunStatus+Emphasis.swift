import MultishellServices

extension CIRunStatus {
  /// A failed check or job is written in full strength; the rest recede.
  public var drawsAttention: Bool { self == .failed }
}

import MultishellServices

extension CIRunStatus {
  /// A failed job is written in full strength; the rest recede.
  public var drawsAttention: Bool { self == .failed }
}

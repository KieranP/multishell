extension DiffSide {
  /// Read under `shown`: the file on disk always, the committed side only under the
  /// scope a card was written in, `HEAD` and the base holding different text.
  public func isRead(under shown: ChangeScope, writtenUnder written: ChangeScope) -> Bool {
    self == .onDisk || written == shown
  }
}

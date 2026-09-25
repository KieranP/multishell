extension PresentedError {
  /// The stronger form and the button naming it, one value so neither can be
  /// set without the other.
  public struct Retry {
    public let label: String
    public let action: @MainActor () async -> Void

    init(label: String, action: @escaping @MainActor () async -> Void) {
      self.label = label
      self.action = action
    }
  }
}

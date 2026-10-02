extension PresentedError {
  /// The stronger form and the button naming it, one value so neither can be
  /// set without the other.
  public struct Retry {
    public let label: String
    let action: @MainActor () async -> Void
  }
}

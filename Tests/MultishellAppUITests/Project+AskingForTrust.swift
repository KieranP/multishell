@testable import MultishellCore

extension Project {
  /// The tallest the hooks page's Create group gets: the trust section
  /// stands above it.
  @MainActor
  func askingForTrust() -> Project {
    let shared = SharedProjectSettings(preCreateHook: "make setup", postCreateHook: "npm ci")
    var asking = self
    asking.sharedSettings = SharedSettingsSnapshot(
      asWritten: shared, confined: shared, hasBeenRead: true)
    return asking
  }
}

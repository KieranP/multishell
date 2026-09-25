import Foundation
import MultishellCore

/// One read of a repository's `.multishell.json`: what it said, the same held
/// to the checkout, and its date. Both touch the disk; see settings.md.
struct SharedSettingsReading: Sendable {
  let result: Result<SharedProjectSettings?, any Error>
  let confined: SharedProjectSettings?
  let stamp: Date

  /// Confined here, off the main actor, as it resolves symlinks per path.
  init(result: Result<SharedProjectSettings?, any Error>, stamp: Date, project: Project) {
    self.result = result
    self.confined = (try? result.get())??.confined(to: project)
    self.stamp = stamp
  }
}

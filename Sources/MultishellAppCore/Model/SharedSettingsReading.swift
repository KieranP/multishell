import Foundation
import MultishellCore

/// One read of a repository's `.multishell.json`: what it said, the same held
/// to the checkout, and its date. Both touch the disk; see settings.md.
struct SharedSettingsReading: Sendable {
  let result: Result<SharedProjectSettings?, any Error>
  let confined: SharedProjectSettings?
  let stamp: Date
}

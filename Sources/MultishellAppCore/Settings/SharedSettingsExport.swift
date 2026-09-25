import Foundation
import MultishellCore

/// One export of a repository's file, the bytes decided on the main actor and
/// written off it by `AppModel.write(_:)`, in the order they were asked.
struct SharedSettingsExport: Sendable {
  let project: Project
  let data: Data
  /// What was written, digest and all, so nothing turns on reading the file
  /// back and finding the bytes this run put there.
  let written: SharedProjectSettings
  let order: SaveOrder
  let ticket: SaveOrder.Ticket
}

import Foundation
import MultishellCore

/// One export of a repository's file, the bytes decided on the main actor and
/// written off it by `write()`, in the order they were asked.
struct SharedSettingsExport: Sendable {
  let project: Project
  let contents: Data
  /// What was written, digest and all, so nothing turns on reading the file
  /// back and finding the bytes this run put there.
  let written: SharedProjectSettings
  let order: SaveOrder
  let ticket: SaveOrder.Ticket

  /// `nil` where a later export landed first, which leaves the file to it.
  func write() -> Result<SharedSettingsReading?, any Error> {
    let file = SharedProjectSettings.file(in: project.path)
    return Result {
      let stamp = try order.land(ticket) {
        try contents.write(to: file, options: .atomic)
        return SharedSettingsReading.modificationDate(of: file)
      }
      return stamp.map { date in
        SharedSettingsReading(loaded: .success(written), modificationDate: date, project: project)
      }
    }
  }
}

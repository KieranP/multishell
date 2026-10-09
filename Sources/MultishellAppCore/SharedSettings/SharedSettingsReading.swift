import Foundation
import MultishellCore

/// One read of a repository's `.multishell.json`: what it said, the same held
/// to the checkout, and its date. Both touch the disk; see settings.md.
struct SharedSettingsReading: Sendable {
  let loaded: Result<SharedProjectSettings?, any Error>
  let confined: SharedProjectSettings?
  let modificationDate: Date

  /// Confined here, off the main actor, as it resolves symlinks per path.
  init(
    loaded: Result<SharedProjectSettings?, any Error>,
    modificationDate: Date,
    project: Project,
  ) {
    self.loaded = loaded
    self.confined = (try? loaded.get())??.confined(to: project)
    self.modificationDate = modificationDate
  }

  /// The file, the confinement and the date it had, the date taken first so a
  /// write landing mid-read is caught by the next tick. Off the main actor.
  static func read(from project: Project) -> Self {
    let stamp = modificationDate(of: SharedProjectSettings.file(in: project.path))
    let loaded = Result { try SharedProjectSettings.load(from: project.path) }
    return Self(loaded: loaded, modificationDate: stamp, project: project)
  }

  /// `.distantPast` for a file that is not there, so its arrival reads as a
  /// change like any other.
  static func modificationDate(of file: URL) -> Date {
    file.modificationDate ?? .distantPast
  }
}

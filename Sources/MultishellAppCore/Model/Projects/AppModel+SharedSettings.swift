import Foundation
import MultishellCore

extension AppModel {
  /// The file, the confinement and the date it had, the date taken first so a
  /// write landing mid-read is caught by the next tick. Off the main actor.
  nonisolated static func readSharedSettings(of project: Project) -> SharedSettingsReading {
    let stamp = modificationDate(of: SharedProjectSettings.file(in: project.path))
    let result = Result { try SharedProjectSettings.load(from: project.path) }
    return SharedSettingsReading(result: result, stamp: stamp, project: project)
  }

  /// `.distantPast` for a file that is not there, so its arrival reads as a
  /// change like any other.
  nonisolated static func modificationDate(of file: URL) -> Date {
    (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
      ?? .distantPast
  }

  /// Every project's file, re-read where its date moved. On the status poll,
  /// the watcher watching only `.git`; an unreachable repository is skipped.
  func refreshSharedSettingsIfChanged() async {
    for project in workspace.projects where !missingProjects.contains(project.id) {
      await refreshSharedSettingsIfChanged(project)
    }
  }

  /// A tick's check for a file edited while the app is up, `refresh` running
  /// only when the records change. One stat per project per tick.
  func refreshSharedSettingsIfChanged(_ project: Project) async {
    let path = project.path
    let stamp = await offMain {
      Self.modificationDate(of: SharedProjectSettings.file(in: path))
    }
    guard project.sharedSettings.hasMoved(stamp) else { return }
    let reading = await offMain { Self.readSharedSettings(of: project) }
    guard workspace.project(project.id) != nil else { return }
    applySharedSettingsReading(reading, for: project)
  }

  /// The confinement against the disk again: the verdict is reached when the
  /// file is read, and a branch can add a symlink without moving its bytes.
  func reconfineSharedSettings(of project: Project) async -> Project {
    guard let shared = workspace.project(project.id)?.sharedSettings.asWritten
    else { return workspace.project(project.id) ?? project }
    let confined = await offMain { shared.confined(to: project) }
    guard var snapshot = workspace.project(project.id)?.sharedSettings,
      snapshot.asWritten == shared, snapshot.confined != confined
    else { return workspace.project(project.id) ?? project }
    snapshot.confined = confined
    store.updateSharedSettings(snapshot, forProject: project.id)
    return workspace.project(project.id) ?? project
  }

  /// What a refresh read, a file that will not parse costing the shared
  /// settings and not the project. Hooks changed under the user are asked here.
  func applySharedSettingsReading(_ reading: SharedSettingsReading, for project: Project) {
    // The workspace's copy, not the caller's: a refresh reads the file, then
    // awaits git, and a tick's read landing meanwhile is not this one to undo.
    let project = workspace.project(project.id) ?? project
    var snapshot = project.sharedSettings
    let firstRead = !snapshot.hasBeenRead
    let stamp = reading.stamp
    switch reading.result {
    case .success(let shared):
      // The date is recorded whatever the bytes say: a touch moves it
      // without changing them, and an unrecorded date is re-read every tick.
      let changed = snapshot.asWritten != shared || firstRead
      snapshot.recordParsed(shared, confined: reading.confined, modificationDate: stamp)
      store.updateSharedSettings(snapshot, forProject: project.id)
      guard changed else { return }
      // A question already up is about a file the disk no longer has, and
      // trusting it would store an answer for bytes nobody committed.
      let wasAsking = pendingSharedSettingsTrust?.projectID == project.id
      if wasAsking, pendingSharedSettingsTrust?.digest != shared?.digest {
        pendingSharedSettingsTrust = nil
      }
      if !firstRead, wasAsking || workspace.selectedWorktree?.projectID == project.id {
        askAboutSharedSettingsIfNeeded(for: project.id)
      }
    case .failure(let error):
      // A question up names hooks the app no longer has, so it goes the way
      // a deleted file's does, and returns if the file parses again.
      dismissSharedSettingsTrust(for: project.id)
      let problem = t(
        "error.shared-settings-unreadable", SharedProjectSettings.fileName,
        String(describing: error))
      let isNew = snapshot.problem != problem
      snapshot.recordFailure(problem: problem, modificationDate: stamp)
      store.updateSharedSettings(snapshot, forProject: project.id)
      if isNew { platform.log("\(project.name): \(problem)") }
    }
  }
}

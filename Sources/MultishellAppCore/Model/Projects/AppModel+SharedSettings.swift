import Foundation
import MultishellCore

extension AppModel {
  /// Every project's file, re-read where its date moved. On the status poll,
  /// the watcher watching only `.git`; an unreachable repository is skipped.
  func refreshSharedSettingsIfChanged() async {
    for project in workspace.projects where !missingProjects.contains(project.id) {
      await refreshSharedSettingsIfChanged(project)
    }
  }

  /// A tick's check for a file edited while the app is up, `refreshWorktrees` running
  /// only when the records change. One stat per project per tick.
  func refreshSharedSettingsIfChanged(_ project: Project) async {
    let path = project.path
    let stamp = await runOnDispatch {
      SharedSettingsReading.modificationDate(of: SharedProjectSettings.file(in: path))
    }
    guard project.sharedSettingsSnapshot.needsRead(at: stamp) else { return }
    let reading = await runOnDispatch { SharedSettingsReading.read(from: project) }
    guard workspace.project(project.id) != nil else { return }
    applySharedSettingsReading(reading, for: project)
  }

  /// The confinement against the disk again: the verdict is reached when the
  /// file is read, and a branch can add a symlink without moving its bytes.
  func reconfineSharedSettings(of project: Project) async -> Project {
    guard let shared = workspace.project(project.id)?.sharedSettingsSnapshot.asWritten
    else { return currentCopy(of: project) }
    let confined = await runOnDispatch { shared.confined(to: project) }
    guard var snapshot = workspace.project(project.id)?.sharedSettingsSnapshot,
      snapshot.asWritten == shared, snapshot.confined != confined
    else { return currentCopy(of: project) }
    snapshot.confined = confined
    store.setSharedSettingsSnapshot(snapshot, forProject: project.id)
    return currentCopy(of: project)
  }

  /// What a refresh read, a file that will not parse costing the shared
  /// settings and not the project. Hooks changed under the user are asked here.
  func applySharedSettingsReading(_ reading: SharedSettingsReading, for project: Project) {
    // The workspace's copy, not the caller's: a refresh reads the file, then
    // awaits git, and a tick's read landing meanwhile is not this one to undo.
    let project = currentCopy(of: project)
    switch reading.loaded {
    case .success(let shared):
      applyParsedSharedSettings(shared, from: reading, for: project)

    case .failure(let error):
      applyUnreadableSharedSettings(error, from: reading, for: project)
    }
  }

  private func applyParsedSharedSettings(
    _ shared: SharedProjectSettings?,
    from reading: SharedSettingsReading,
    for project: Project,
  ) {
    var snapshot = project.sharedSettingsSnapshot
    let isFirstRead = !snapshot.hasBeenRead
    // The date is recorded whatever the bytes say: a touch moves it
    // without changing them, and an unrecorded date is re-read every tick.
    let changed = snapshot.asWritten != shared || isFirstRead
    snapshot.recordParsed(
      shared,
      confined: reading.confined,
      modificationDate: reading.modificationDate,
    )
    store.setSharedSettingsSnapshot(snapshot, forProject: project.id)
    guard changed else { return }
    // A question already up is about a file the disk no longer has, and
    // trusting it would store an answer for bytes nobody committed.
    let wasAsking = pendingSharedSettingsTrust?.projectID == project.id
    if wasAsking, pendingSharedSettingsTrust?.digest != shared?.digest {
      pendingSharedSettingsTrust = nil
    }
    if !isFirstRead, wasAsking || workspace.selectedWorktree?.projectID == project.id {
      askAboutSharedSettingsIfNeeded(for: project.id)
    }
  }

  private func applyUnreadableSharedSettings(
    _ error: any Error,
    from reading: SharedSettingsReading,
    for project: Project,
  ) {
    // A question up names hooks the app no longer has, so it goes the way
    // a deleted file's does, and returns if the file parses again.
    dismissSharedSettingsTrust(for: project.id)
    var snapshot = project.sharedSettingsSnapshot
    let problem = t(
      "error.shared-settings-unreadable",
      SharedProjectSettings.fileName,
      String(describing: error),
    )
    let isNew = snapshot.problem != problem
    snapshot.recordFailure(problem: problem, modificationDate: reading.modificationDate)
    store.setSharedSettingsSnapshot(snapshot, forProject: project.id)
    if isNew { platform.log("\(project.name): \(problem)") }
  }
}

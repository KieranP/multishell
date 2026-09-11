import Foundation
import MultishellCore

// MARK: - The repository's own settings

extension AppModel {
  /// The project's settings with its repository's file filling the gaps, and
  /// what every path, hook and icon decision reads.
  public func effectiveSettings(for project: Project) -> ProjectSettings {
    project.settings.layered(over: sharedSettings[project.id])
  }

  /// The project as the git layer should see it, hooks and overrides
  /// resolved.
  func resolved(_ project: Project) -> Project {
    var resolved = project
    resolved.settings = effectiveSettings(for: project)
    return resolved
  }

  /// Where this project's worktrees go and how their branches are named,
  /// after the repository's defaults and the user's overrides.
  public func worktreeSettings(for project: Project) -> WorktreeSettings {
    effectiveSettings(for: project).effective(defaults: workspace.worktreeDefaults)
  }

  /// The value in force where this project does not override, and where it
  /// came from. What the settings forms show and seed an override with.
  public func inherited<Value: Equatable & Sendable>(
    _ keyPath: KeyPath<SharedProjectSettings, Value?>, global: Value, for project: Project
  ) -> InheritedSetting<Value> {
    if let shared = sharedSettings[project.id]?[keyPath: keyPath] {
      return InheritedSetting(value: shared, isFromRepository: true)
    }
    return InheritedSetting(value: global, isFromRepository: false)
  }

  /// Whether the file's hooks are the ones in force for this project.
  public func trustsSharedHooks(of project: Project) -> Bool {
    guard let shared = sharedSettings[project.id] else { return false }
    return project.settings.trustsHooks(of: shared)
  }

  /// The file and the date it had when read, the date taken first so a write
  /// landing mid-read is caught by the next tick.
  nonisolated static func readSharedSettings(
    from repository: URL
  ) -> (
    result: Result<SharedProjectSettings?, any Error>, stamp: Date
  ) {
    let stamp = modificationDate(of: SharedProjectSettings.file(in: repository))
    return (Result { try SharedProjectSettings.load(from: repository) }, stamp)
  }

  /// `.distantPast` for a file that is not there, so its arrival reads as a
  /// change like any other.
  nonisolated static func modificationDate(of file: URL) -> Date {
    (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
      ?? .distantPast
  }

  /// Every project's file, re-read where its date moved. On the status poll,
  /// the watcher watching only `.git`; an unreachable repository is skipped.
  func refreshChangedSharedSettings() async {
    for project in workspace.projects where !missingProjects.contains(project.id) {
      await refreshSharedSettingsIfChanged(project)
    }
  }

  /// A tick's check for a file edited while the app is up, `refresh` running
  /// only when the records change. One stat per project per tick.
  func refreshSharedSettingsIfChanged(_ project: Project) async {
    let path = project.path
    let stamp = await Self.offMain {
      Self.modificationDate(of: SharedProjectSettings.file(in: path))
    }
    guard sharedSettings.hasMoved(stamp, for: project.id) else { return }
    let read = await Self.offMain { Self.readSharedSettings(from: path) }
    guard workspace.project(project.id) != nil else { return }
    noteSharedSettings(read.result, stamp: read.stamp, for: project)
  }

  /// What a refresh read, a file that will not parse costing the shared
  /// settings and not the project. Hooks changed under the user are asked here.
  func noteSharedSettings(
    _ result: Result<SharedProjectSettings?, any Error>, stamp: Date, for project: Project
  ) {
    let firstRead = !sharedSettings.hasRead(project.id)
    switch result {
    case .success(let shared):
      guard sharedSettings.note(shared, stamp: stamp, for: project.id) else { return }
      // A question already up is about a file the disk no longer has, and
      // trusting it would store an answer for bytes nobody committed.
      let wasAsking = pendingSharedHooksTrust?.projectID == project.id
      if wasAsking, pendingSharedHooksTrust?.digest != shared?.digest {
        pendingSharedHooksTrust = nil
      }
      if !firstRead, wasAsking || workspace.selectedWorktree?.projectID == project.id {
        askAboutSharedHooksIfNeeded(for: project.id)
      }
    case .failure(let error):
      // A question up names hooks the app no longer has, so it goes the way
      // a deleted file's does, and returns if the file parses again.
      if pendingSharedHooksTrust?.projectID == project.id { pendingSharedHooksTrust = nil }
      let problem = "\(SharedProjectSettings.fileName) could not be read: \(error)"
      if sharedSettings.note(problem: problem, stamp: stamp, for: project.id) {
        platform.log("\(project.name): \(problem)")
      }
    }
  }

  /// Asked when the user turns to the project, not when a refresh finds the
  /// file: a launch would otherwise open with a queue of questions.
  func askAboutSharedHooksIfNeeded(for id: Project.ID) {
    // Never over the new-worktree sheet or its create: two on one window
    // fight, and the question returns on the next selection.
    guard newWorktreeRequest == nil, worktreeCreationStep == nil else { return }
    guard pendingSharedHooksTrust == nil, let project = workspace.project(id),
      let shared = sharedSettings[id], let hooks = shared.hooksText, let digest = shared.digest,
      project.settings.needsHookDecision(for: shared)
    else { return }
    pendingSharedHooksTrust = PendingSharedHooksTrust(
      projectID: id, projectName: project.name, hooks: hooks, digest: digest)
  }

  /// Stores an answer against the file's sha256. The project is read again,
  /// a settings window outliving the refresh that replaced its record.
  private func recordSharedHooks(file digest: String, trusted: Bool, for id: Project.ID) {
    guard var settings = workspace.project(id)?.settings else { return }
    settings.recordSharedHooks(file: digest, trusted: trusted)
    store.updateSettings(settings, forProject: id)
  }

  /// The dialog's answer. Either way the question is not asked again for
  /// this file, this branch's or another's.
  public func decideSharedHooks(_ pending: PendingSharedHooksTrust, trusted: Bool) {
    recordSharedHooks(file: pending.digest, trusted: trusted, for: pending.projectID)
    // The whole value, not its project: a different question that arrived
    // while this one stood is not answered by it.
    if pendingSharedHooksTrust == pending { pendingSharedHooksTrust = nil }
  }

  /// Export from the General tab: the settings in effect, written to the
  /// repository's file. The hooks are the user's own words, so trusted.
  public func exportSharedSettings(for project: Project) {
    guard let current = workspace.project(project.id) else { return }
    let shared: SharedProjectSettings
    do {
      // What was written, digest and all, so nothing turns on reading the
      // file back and finding the bytes this run put there.
      shared = try SharedProjectSettings(exporting: effectiveSettings(for: current))
        .write(to: current.path)
    } catch {
      report(error)
      return
    }
    let stamp = Self.modificationDate(of: SharedProjectSettings.file(in: current.path))
    if shared.hasHooks, let digest = shared.digest {
      recordSharedHooks(file: digest, trusted: true, for: current.id)
    }
    noteSharedSettings(.success(shared), stamp: stamp, for: current)
  }

  /// From the project's Hooks tab: trust the file's current hooks, or stop.
  public func setTrustsSharedHooks(_ trusted: Bool, for project: Project) {
    guard let shared = sharedSettings[project.id], shared.hasHooks, let digest = shared.digest
    else { return }
    recordSharedHooks(file: digest, trusted: trusted, for: project.id)
    if pendingSharedHooksTrust?.projectID == project.id { pendingSharedHooksTrust = nil }
  }
}

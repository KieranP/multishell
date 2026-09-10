import Foundation
import MultishellCore

// MARK: - The repository's own settings

extension AppModel {
  /// The project's settings with its repository's `.multishell.json`
  /// filling the gaps; see `ProjectSettings.layered`. What every path,
  /// hook and icon decision reads.
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

  /// The value in force for a flag this project does not override, and
  /// where it comes from: the repository's file where it says, else the
  /// user's global. What the project settings forms show and seed an
  /// override with.
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

  /// The file and the date it had when it was read. The date is taken
  /// first, so a write landing during the read is caught by the next tick
  /// rather than passed over as the version just read.
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

  /// Every project's file, re-read where its date has moved. On the status
  /// poll because nothing else would see it: the watcher watches `.git`,
  /// and a poll's `git status` carries `--no-optional-locks` so that it
  /// writes no index for the watcher to notice. An edit made with the app
  /// frontmost would otherwise wait for a worktree to come or go.
  /// A project whose repository is unreachable is left alone: its stat is
  /// the one that would block on a dead mount, and its hooks cannot run
  /// while it is gone. The refresh that finds it again reads the file.
  func refreshChangedSharedSettings() async {
    for project in workspace.projects where !missingProjects.contains(project.id) {
      await refreshSharedSettingsIfChanged(project)
    }
  }

  /// A tick's check for a file edited while the app is up. `refresh` reads
  /// it, but runs only when the worktree records change, so an edited hook
  /// would otherwise stay the version this run started with until a
  /// worktree came or went. One stat per project per tick is what it costs;
  /// only a file whose date has moved is read.
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

  /// What a refresh read from the repository. A file that will not parse
  /// costs the shared settings, not the project; the Hooks tab says why.
  ///
  /// Hooks that change under the project the user is looking at are asked
  /// about here rather than waiting for the next selection by hand: the
  /// next thing they do may be the create the hook was edited for, and an
  /// untrusted hook does not run. The first read of a project says nothing,
  /// so a launch still opens without a queue of questions.
  func noteSharedSettings(
    _ result: Result<SharedProjectSettings?, any Error>, stamp: Date, for project: Project
  ) {
    let firstRead = !sharedSettings.hasRead(project.id)
    switch result {
    case .success(let shared):
      guard sharedSettings.note(shared, stamp: stamp, for: project.id) else { return }
      // A question already up for this project is about a file the disk no
      // longer has, and trusting it would store an answer for bytes nobody
      // committed. It gives way to one about what the file says now.
      let wasAsking = pendingSharedHooksTrust?.projectID == project.id
      if wasAsking, pendingSharedHooksTrust?.digest != shared?.digest {
        pendingSharedHooksTrust = nil
      }
      if !firstRead, wasAsking || workspace.selectedWorktree?.projectID == project.id {
        askAboutSharedHooksIfNeeded(for: project.id)
      }
    case .failure(let error):
      // A question up for this project names hooks the app no longer has,
      // and nothing it ran would come from the file it was asked about, so
      // it goes the way a deleted file's does. It comes back if the file
      // parses again.
      if pendingSharedHooksTrust?.projectID == project.id { pendingSharedHooksTrust = nil }
      let problem = "\(SharedProjectSettings.fileName) could not be read: \(error)"
      if sharedSettings.note(problem: problem, stamp: stamp, for: project.id) {
        platform.log("\(project.name): \(problem)")
      }
    }
  }

  /// Asked when the user turns to the project, by selecting one of its
  /// worktrees, not when a refresh finds the file: a launch with several
  /// projects would otherwise open with a queue of questions about
  /// repositories nobody is looking at. Nothing for hooks already decided
  /// about, and nothing over a question already up.
  func askAboutSharedHooksIfNeeded(for id: Project.ID) {
    // Never over the new-worktree sheet or the create it starts: a dialog
    // and a sheet on the same window fight, and the sheet is the one the
    // user is answering. The question comes back on the next selection.
    guard newWorktreeRequest == nil, worktreeCreationStep == nil else { return }
    guard pendingSharedHooksTrust == nil, let project = workspace.project(id),
      let shared = sharedSettings[id], let hooks = shared.hooksText, let digest = shared.digest,
      project.settings.needsHookDecision(for: shared)
    else { return }
    pendingSharedHooksTrust = PendingSharedHooksTrust(
      projectID: id, projectName: project.name, hooks: hooks, digest: digest)
  }

  /// Stores an answer against the sha256 of the file it was about; see
  /// `ProjectSettings.sharedHooks`. The project is read again rather than
  /// taken from the caller: a settings window outlives the refresh that
  /// replaced the record it was opened with. Who takes down the question
  /// still up is the caller's, since the three of them do not agree on it.
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

  /// Export from the General tab: writes the project's settings as they are
  /// in effect, the user's own over the file's, to the repository's
  /// `.multishell.json`, for the team to commit. The hooks are the user's
  /// own words, so they are trusted without asking.
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

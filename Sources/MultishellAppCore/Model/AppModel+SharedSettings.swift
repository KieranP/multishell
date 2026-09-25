import Foundation
import MultishellCore

extension AppModel {
  /// The project's settings with its repository's file filling the gaps, and
  /// what every path, hook and icon decision reads.
  public func effectiveSettings(for project: Project) -> ProjectSettings {
    project.settings.layered(over: project.sharedSettings.confined)
  }

  /// The project as the git layer should see it, hooks and overrides
  /// resolved.
  func resolved(_ project: Project) -> Project {
    var resolved = project
    resolved.settings = effectiveSettings(for: project)
    return resolved
  }

  /// A worktree's project with the repository's file layered in: reading
  /// `project.settings` would pass over what the file says.
  func resolvedProject(of worktree: Worktree) -> Project? {
    workspace.project(worktree.projectID).map(resolved)
  }

  /// Where this project's worktrees go and how their branches are named,
  /// after the repository's defaults and the user's overrides.
  public func worktreeSettings(for project: Project) -> WorktreeSettings {
    effectiveSettings(for: project).effective(defaults: workspace.worktreeDefaults)
  }

  /// The value in force where this project does not override, and where it
  /// came from. What the settings forms show and seed an override with.
  public func inherited<Value: Equatable & Sendable>(
    _ setting: InheritableSetting<Value>, global: Value, for project: Project
  ) -> InheritedSetting<Value> {
    if let shared = sharedSettingsInForce(for: project)?[keyPath: setting.shared] {
      return InheritedSetting(value: shared, isFromRepository: true)
    }
    return InheritedSetting(value: global, isFromRepository: false)
  }

  /// The repository's settings as they apply here, what the yes covers dropped
  /// until it is given. The same view `layered` resolves against.
  private func sharedSettingsInForce(for project: Project) -> SharedProjectSettings? {
    guard let shared = project.sharedSettings.confined else { return nil }
    return project.settings.trustsSharedSettings(of: shared)
      ? shared : shared.withoutWhatTrustCovers
  }

  /// Whether what the file asks for is in force for this project.
  public func trustsSharedSettings(of project: Project) -> Bool {
    guard let shared = project.sharedSettings.confined else { return false }
    return project.settings.trustsSharedSettings(of: shared)
  }

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
    let read = await offMain { Self.readSharedSettings(of: project) }
    guard workspace.project(project.id) != nil else { return }
    noteSharedSettings(read, for: project)
  }

  /// The confinement against the disk again: the verdict is reached when the
  /// file is read, and a branch can add a symlink without moving its bytes.
  func reconfineSharedSettings(of project: Project) async -> Project {
    guard let shared = workspace.project(project.id)?.sharedSettings.asWritten
    else { return workspace.project(project.id) ?? project }
    let confined = await offMain { shared.confined(to: project) }
    guard var read = workspace.project(project.id)?.sharedSettings, read.asWritten == shared,
      read.confined != confined
    else { return workspace.project(project.id) ?? project }
    read.confined = confined
    store.updateSharedSettings(read, forProject: project.id)
    return workspace.project(project.id) ?? project
  }

  /// What a refresh read, a file that will not parse costing the shared
  /// settings and not the project. Hooks changed under the user are asked here.
  func noteSharedSettings(_ reading: SharedSettingsReading, for project: Project) {
    // The workspace's copy, not the caller's: a refresh reads the file, then
    // awaits git, and a tick's read landing meanwhile is not this one to undo.
    let project = workspace.project(project.id) ?? project
    var read = project.sharedSettings
    let firstRead = !read.hasBeenRead
    let stamp = reading.stamp
    switch reading.result {
    case .success(let shared):
      // The date is recorded whatever the bytes say: a touch moves it
      // without changing them, and an unrecorded date is re-read every tick.
      let changed = read.asWritten != shared || firstRead
      read.recordParsed(shared, confined: reading.confined, modificationDate: stamp)
      store.updateSharedSettings(read, forProject: project.id)
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
      if pendingSharedSettingsTrust?.projectID == project.id { pendingSharedSettingsTrust = nil }
      let problem = t(
        "error.shared-settings-unreadable", SharedProjectSettings.fileName,
        String(describing: error))
      let isNew = read.problem != problem
      read.recordFailure(problem: problem, modificationDate: stamp)
      store.updateSharedSettings(read, forProject: project.id)
      if isNew { platform.log("\(project.name): \(problem)") }
    }
  }

  /// Asked when the user turns to the project, not when a refresh finds the
  /// file: a launch would otherwise open with a queue of questions.
  func askAboutSharedSettingsIfNeeded(for id: Project.ID) {
    // Never over the new-worktree sheet or its create: two on one window
    // fight, and the question returns on the next selection.
    guard newWorktreeRequest == nil, worktreeCreationStep == nil else { return }
    guard pendingSharedSettingsTrust == nil, let project = workspace.project(id),
      let shared = project.sharedSettings.confined, let contents = shared.trustCoveredText,
      let digest = shared.digest, project.settings.needsTrustDecision(for: shared)
    else { return }
    pendingSharedSettingsTrust = PendingSharedSettingsTrust(
      projectID: id, projectName: project.name, contents: contents, digest: digest)
  }

  /// Stores an answer against the file's sha256. The project is read again,
  /// a settings window outliving the refresh that replaced its record.
  private func recordTrustDecision(digest: String, trusted: Bool, for id: Project.ID) {
    guard var settings = workspace.project(id)?.settings else { return }
    settings.recordTrustDecision(digest: digest, trusted: trusted)
    store.updateSettings(settings, forProject: id)
  }

  /// The dialog's answer. Either way the question is not asked again for
  /// this file, this branch's or another's.
  public func decideSharedSettings(_ pending: PendingSharedSettingsTrust, trusted: Bool) {
    recordTrustDecision(digest: pending.digest, trusted: trusted, for: pending.projectID)
    // The whole value, not its project: a different question that arrived
    // while this one stood is not answered by it.
    if pendingSharedSettingsTrust == pending { pendingSharedSettingsTrust = nil }
  }

  /// Export from the General tab. A refused hook or path list the file held
  /// is kept, and stays refused.
  public func exportSharedSettings(for project: Project) async {
    let export: SharedSettingsExport
    do {
      guard let prepared = try prepareSharedSettingsExport(for: project) else { return }
      export = prepared
    } catch {
      report(error)
      return
    }
    // The write, its date and the confinement off the main actor: on a slow
    // volume each would hold the window.
    let written = await offMain { Self.write(export) }
    finishSharedSettingsExport(export, written)
  }

  /// `nil` for a project gone from the workspace between the click and here,
  /// rather than writing a file into a project the user removed.
  func prepareSharedSettingsExport(for project: Project) throws -> SharedSettingsExport? {
    guard let project = workspace.project(project.id) else { return nil }
    let mine = SharedProjectSettings(exporting: effectiveSettings(for: project))
    let kept = mine.keeping(from: project.sharedSettings.asWritten)
    // Every word the user's own answers itself; otherwise the answer given
    // about the file this rewrites travels, and no answer leaves the question.
    let answer =
      kept.trustCoveredText == mine.trustCoveredText
      ? true
      : project.sharedSettings.confined.flatMap {
        project.settings.trustAnswer(about: $0)
      }
    let (data, written) = try kept.fileContents()
    // Stored before the bytes can be read: a poll reading them first would
    // otherwise ask the user to trust what they just exported.
    if written.asksForTrust, let digest = written.digest, let answer {
      recordTrustDecision(digest: digest, trusted: answer, for: project.id)
    }
    let order = sharedSettingsWrites[project.id] ?? SaveOrder()
    sharedSettingsWrites[project.id] = order
    return SharedSettingsExport(
      project: project, data: data, written: written, order: order, ticket: order.issue())
  }

  /// `nil` where a later export landed first, which leaves the file to it.
  nonisolated static func write(
    _ export: SharedSettingsExport
  ) -> Result<SharedSettingsReading?, any Error> {
    let file = SharedProjectSettings.file(in: export.project.path)
    return Result {
      let stamp = try export.order.land(export.ticket) {
        try export.data.write(to: file, options: .atomic)
        return modificationDate(of: file)
      }
      return stamp.map {
        SharedSettingsReading(result: .success(export.written), stamp: $0, project: export.project)
      }
    }
  }

  func finishSharedSettingsExport(
    _ export: SharedSettingsExport, _ written: Result<SharedSettingsReading?, any Error>
  ) {
    let project = export.project
    guard workspace.project(project.id) != nil else { return }
    switch written {
    case .failure(let error):
      report(error)
    case .success(let reading?) where export.order.isLastLanded(export.ticket):
      noteSharedSettings(reading, for: project)
    case .success:
      break
    }
  }

  /// From the project's Hooks tab: trust what the file currently asks for,
  /// or stop.
  public func setTrustsSharedSettings(_ trusted: Bool, for project: Project) {
    // A button's action runs after the render that built it, so this one
    // copy can be a read behind; the digest decides what trust is stored.
    let project = workspace.project(project.id) ?? project
    guard let shared = project.sharedSettings.confined, shared.asksForTrust,
      let digest = shared.digest
    else { return }
    recordTrustDecision(digest: digest, trusted: trusted, for: project.id)
    if pendingSharedSettingsTrust?.projectID == project.id { pendingSharedSettingsTrust = nil }
  }
}

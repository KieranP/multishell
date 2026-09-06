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

  /// Whether the file's hooks are the ones in force for this project.
  public func trustsSharedHooks(of project: Project) -> Bool {
    guard let shared = sharedSettings[project.id] else { return false }
    return project.settings.trustsHooks(of: shared)
  }

  /// What a refresh read from the repository. A file that will not parse
  /// costs the shared settings, not the project; the Hooks tab says why.
  func noteSharedSettings(
    _ result: Result<SharedProjectSettings?, any Error>, for project: Project
  ) {
    switch result {
    case .success(let shared):
      sharedSettingsProblems[project.id] = nil
      if sharedSettings[project.id] != shared { sharedSettings[project.id] = shared }
    case .failure(let error):
      sharedSettings[project.id] = nil
      let problem = "\(SharedProjectSettings.fileName) could not be read: \(error)"
      if sharedSettingsProblems[project.id] != problem {
        sharedSettingsProblems[project.id] = problem
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
    guard pendingSharedHooksTrust == nil, let project = workspace.project(id),
      let shared = sharedSettings[id], let hooks = shared.hooksText,
      project.settings.needsHookDecision(for: shared)
    else { return }
    pendingSharedHooksTrust = PendingSharedHooksTrust(
      projectID: id, projectName: project.name, hooks: hooks)
  }

  /// The dialog's answer. Either way the question is not asked again for
  /// this text.
  public func decideSharedHooks(_ pending: PendingSharedHooksTrust, trusted: Bool) {
    if let project = workspace.project(pending.projectID) {
      var settings = project.settings
      settings.sharedHooks = SharedHooksDecision(hooks: pending.hooks, trusted: trusted)
      store.updateSettings(settings, forProject: project.id)
    }
    if pendingSharedHooksTrust == pending { pendingSharedHooksTrust = nil }
  }

  /// Export from the General tab: writes the project's settings as they are
  /// in effect, the user's own over the file's, to the repository's
  /// `.multishell.json`, for the team to commit. The hooks are the user's
  /// own words, so they are trusted without asking.
  public func exportSharedSettings(for project: Project) {
    guard let current = workspace.project(project.id) else { return }
    let shared = SharedProjectSettings(exporting: effectiveSettings(for: current))
    do {
      try shared.write(to: current.path)
    } catch {
      report(error)
      return
    }
    if let hooks = shared.hooksText {
      var settings = current.settings
      settings.sharedHooks = SharedHooksDecision(hooks: hooks, trusted: true)
      store.updateSettings(settings, forProject: current.id)
    }
    noteSharedSettings(.success(shared), for: current)
  }

  /// From the project's Hooks tab: trust the file's current hooks, or stop.
  public func setTrustsSharedHooks(_ trusted: Bool, for project: Project) {
    guard let hooks = sharedSettings[project.id]?.hooksText else { return }
    var settings = workspace.project(project.id)?.settings ?? project.settings
    settings.sharedHooks = SharedHooksDecision(hooks: hooks, trusted: trusted)
    store.updateSettings(settings, forProject: project.id)
    if pendingSharedHooksTrust?.projectID == project.id { pendingSharedHooksTrust = nil }
  }
}

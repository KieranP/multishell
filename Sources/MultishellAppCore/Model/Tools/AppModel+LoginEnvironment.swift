import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// The login shell's environment, and what is looked up on its PATH: agents,
/// shells, editors and git.
extension AppModel {
  /// Which PATH the agents are looked up on, for the agent picker's (i).
  public var agentPathNote: String {
    switch loginEnvironment?.source {
    case nil: t("agents.path-asking")
    case .loginShell(let shell): t("agents.path-from-login-shell", shell.path)
    case .processFallback(let reason): t("agents.path-fallback", reason)
    }
  }

  /// Asks the login shell for its environment once, off the main thread, and
  /// re-runs detection against its PATH.
  public func refreshLoginEnvironment() async {
    let environment = await captureLoginEnvironment()
    if case .processFallback(let reason) = environment.source {
      platform.log("login shell environment unavailable, using the process's own: \(reason)")
    }
    await detectTools(on: environment)
    await adoptGit(on: environment.path)
    recordInstallState(await runOnDispatch { IntegrationInstallState.read() })
  }

  /// Agents, shells and editors, scanned off the main thread and recorded
  /// with the environment they were found on.
  private func detectTools(on environment: LoginShellEnvironment) async {
    // The bundle lookups answer from LaunchServices' own database and need
    // the platform, so they stay; it is the PATH that has to be left.
    let applications = EditorCatalogue.editors.reduce(into: [String: URL]()) { found, editor in
      guard let id = editor.bundleIdentifier, let url = platform.applicationURL(forIdentifier: id)
      else { return }
      found[id] = url
    }
    // A stat per PATH directory per catalogue entry, and every one of them
    // blocks for the timeout on a mount that has gone; see architecture.md.
    let searchPath = environment.path
    let detected = await runOnDispatch {
      (
        agents: AgentDetection(searchPath: searchPath),
        shells: ShellDetection(searchPath: searchPath),
        editors: EditorDetection(searchPath: searchPath) { applications[$0] }
      )
    }
    // Together, after the scan: `agentCommand` reads a set environment as
    // "detection has answered", and the sidebar is already up.
    loginEnvironment = environment
    agentDetection = detected.agents
    shellDetection = detected.shells
    editorDetection = detected.editors
  }

  /// Rebuilt even where launch found git: that PATH is what git's own
  /// children are looked up on; see Docs/design/architecture.md.
  private func adoptGit(on searchPath: String?) async {
    let hadGit = coordinator != nil
    guard
      let found = try? await WorktreeCoordinator.resolved(
        searchPath: searchPath, replacing: coordinator)
    else { return }
    coordinator = found
    // A git found for the first time has a log of its own to switch on.
    found.git.runLog.setRecording(areDebugToolsEnabled)
    guard !hadGit else { return }
    if presentedError?.saysGitIsMissing == true { presentedError = nil }
    // `start` refreshed before this ran and found no git, so every project
    // listed nothing; the sidebar stays empty until something asks again.
    await refreshAll()
  }
}

import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// The login shell's environment, and what is looked up on its PATH: agents,
/// shells, editors and git.
extension AppModel {
  /// Asks the login shell for its environment once, off the main thread, and
  /// re-runs detection against its PATH.
  public func refreshLoginEnvironment() async {
    let environment = await captureLoginEnvironment()
    if case .processFallback(let reason) = environment.source {
      platform.log("login shell environment unavailable, using the process's own: \(reason)")
    }
    // The bundle lookups answer from LaunchServices' own database and need
    // the platform, so they stay; it is the PATH that has to be left.
    let applications = EditorCatalogue.editors.reduce(into: [String: URL]()) { found, editor in
      guard let id = editor.bundleIdentifier, let url = platform.applicationURL(forIdentifier: id)
      else { return }
      found[id] = url
    }
    // A stat per PATH directory per catalogue entry, and every one of them
    // blocks for the timeout on a mount that has gone; see architecture.md.
    let path = environment.path
    let detected = await offMain {
      (
        agents: AgentDetection(path: path), shells: ShellDetection(path: path),
        editors: EditorDetection(path: path) { applications[$0] }
      )
    }
    // Together, after the scan: `agentCommand` reads a set environment as
    // "detection has answered", and the sidebar is already up.
    loginEnvironment = environment
    agentDetection = detected.agents
    shellDetection = detected.shells
    editorDetection = detected.editors
    // Rebuilt even where launch found git: that PATH is what git's own
    // children are looked up on; see Docs/design/architecture.md.
    let hadGit = worktrees != nil
    if let found = try? await WorktreeCoordinator.resolved(
      searchPath: environment.path, replacing: worktrees)
    {
      worktrees = found
      if !hadGit {
        if presentedError?.saysGitIsMissing == true { presentedError = nil }
        // `start` refreshed before this ran and found no git, so every project
        // listed nothing; the sidebar stays empty until something asks again.
        await refreshAll()
      }
    }
    recordInstallState(await offMain { Self.installState() })
  }
}

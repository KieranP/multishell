import AppKit
import MultishellCore
import MultishellGitKit
import Observation
import SwiftUI

/// Wires the core to the Mac GUI: owns the store, the terminal host and the
/// git coordinator, and turns view actions into store mutations.
///
/// Views read `workspace` and call these methods. They never touch the host,
/// the registry or git directly.
@Observable
@MainActor
final class AppModel {
  let host: MultiEngineHost

  var presentedError: PresentedError?
  var newWorktreeProject: Project?
  /// A removal waiting on the confirmation dialog.
  var pendingRemoval: Worktree?
  /// Which project the settings window shows.
  var settingsProjectID: Project.ID?
  /// The workspace window, so window-scoped commands can tell whether they
  /// were issued there or in a settings window.
  @ObservationIgnored weak var mainWindow: NSWindow?

  /// True when a keyboard command should act on the workspace. In any other
  /// window (Settings, Project Settings) Cmd+W must close that window instead
  /// of a pane the user cannot see.
  var workspaceWindowIsKey: Bool {
    // `NSApp` is nil until an application object exists, which it never does
    // under `swift test`; no app means no other window can be key.
    guard let key = NSApp?.keyWindow else { return true }
    return key === mainWindow
  }
  /// Sessions that did something while not focused. Cleared on focus.
  var unseenActivity: Set<TerminalSession.ID> = []
  var themes: [Theme] = Theme.builtins
  /// `git status` per worktree. Runtime only; see `WorktreeStatus`.
  var statuses: [Worktree.ID: WorktreeStatus] = [:]
  /// Sessions with a running shell, mirrored from the host after each
  /// reconcile so views can observe it; the host itself is not observable.
  var liveSessions: Set<TerminalSession.ID> = []
  /// Projects whose directory has gone. Kept in the sidebar, dimmed, rather
  /// than dropped: an unmounted drive should not delete someone's setup.
  var missingProjects: Set<Project.ID> = []
  /// Worktrees whose saved tabs have been given live shells. Empty at launch,
  /// so relaunching with many saved tabs starts nothing; grows as worktrees
  /// are visited and never shrinks while the app runs.
  @ObservationIgnored var warmWorktrees: Set<Worktree.ID> = []

  @ObservationIgnored let store: WorkspaceStore
  @ObservationIgnored let registry: SessionRegistry
  @ObservationIgnored let worktrees: WorktreeCoordinator?
  @ObservationIgnored var pendingSave: Task<Void, Never>?
  @ObservationIgnored let watcher: any DirectoryWatcher
  @ObservationIgnored var statusPolling: Task<Void, Never>?

  var workspace: Workspace { store.workspace }

  convenience init() {
    let (store, loadError) = WorkspaceStore.restored()
    self.init(
      store: store,
      host: MultiEngineHost(engine: store.workspace.terminalEngine),
      worktrees: try? WorktreeCoordinator(),
      watcher: DispatchDirectoryWatcher(),
      loadError: loadError
    )
  }

  /// Dependencies are passed in so tests can run the whole model against
  /// recording engines, a fake watcher and no git.
  init(
    store: WorkspaceStore,
    host: MultiEngineHost,
    worktrees: WorktreeCoordinator?,
    watcher: any DirectoryWatcher,
    loadError: (any Error)? = nil
  ) {
    self.store = store
    self.host = host
    self.registry = SessionRegistry(store: store, host: host)
    self.worktrees = worktrees
    self.watcher = watcher

    reloadThemes()
    host.apply(currentTheme, appearance: store.workspace.appearance)
    if let loadError {
      report(loadError)
    } else if worktrees == nil {
      report(GitUnavailable())
    }

    // Nothing is selected at launch, so no shell starts until the user picks
    // a worktree. Saved tabs stay saved and open with that first click.
    store.selectWorktree(nil)

    // Statuses only poll while frontmost, so coming back from another app
    // would otherwise show badges up to five seconds stale.
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in await self?.refreshAll() }
    }

    registry.onActivity = { [weak self] id in self?.noteActivity(in: id) }
    registry.onLiveSessionsChanged = { [weak self] in
      guard let self else { return }
      let live = registry.liveSessionIDs
      if live != liveSessions { liveSessions = live }
    }
    watcher.onChange = { [weak self] in Task { await self?.refreshWorktrees() } }
    observeForAutosave()
  }

  /// Shells actually running, as opposed to saved tabs waiting to be opened.
  var liveTerminalCount: Int { liveSessions.count }

  func liveTerminalCount(in worktree: Worktree.ID) -> Int {
    workspace.sessions(in: worktree).filter { liveSessions.contains($0.id) }.count
  }

  var currentTheme: Theme {
    workspace.appearance.theme(from: themes)
  }

  var metrics: UIMetrics {
    UIMetrics(fontSize: workspace.appearance.uiFontSize)
  }

  /// Restores the sidebar from disk, then asks git what each project
  /// actually has. Terminals are not restored; only the tree is.
  func start() async {
    await refreshAll()
    sync()
    startStatusPolling()
  }

  func refreshAll() async {
    await refreshWorktrees()
    await refreshStatuses()
  }

  func refreshWorktrees() async {
    for project in workspace.projects {
      await refresh(project)
    }
    await rearmWatcher()
  }

  /// Re-read after every refresh: a new worktree adds a directory that must
  /// itself be watched for branch changes.
  func rearmWatcher() async {
    guard let worktrees else { return }
    var directories: [URL] = []
    for project in workspace.projects {
      directories += await worktrees.directoriesToWatch(for: project)
    }
    watcher.watch(directories)
  }
}

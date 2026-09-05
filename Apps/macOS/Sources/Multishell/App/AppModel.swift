import AppKit
import MultishellCore
import MultishellGitKit
import MultishellProcess
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
  var newWorktreeRequest: NewWorktreeRequest?
  /// A removal waiting on the confirmation dialog.
  var pendingRemoval: Worktree?
  /// A project removal waiting on its dialog, in whichever window asked.
  var pendingProjectRemoval: PendingProjectRemoval?
  /// A pane or tab close waiting on it, because an agent there is working.
  var pendingClose: PendingClose?
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
  /// What each live terminal is doing, from the engine and from reports over
  /// the socket; see `SessionStates` for who clears what.
  var sessionStates = SessionStates()
  /// The environment of the user's interactive login shell, once captured.
  /// `nil` until the shell has answered.
  var loginEnvironment: LoginShellEnvironment?
  /// Which catalogue agents that environment's PATH has.
  var agentDetection = AgentDetection.empty
  /// Which shells the machine has, from `/etc/shells` and that PATH.
  var shellDetection = ShellDetection.empty
  /// Which catalogue editors are installed, by bundle id or shim.
  var editorDetection = EditorDetection.empty
  var claudeHooksInstalled = false
  var commandLineToolInstalled = false
  var themes: [Theme] = Theme.builtins
  /// `git status` per worktree. Runtime only; see `WorktreeStatus`.
  var statuses: [Worktree.ID: WorktreeStatus] = [:]
  /// Sessions with a running shell, mirrored from the host after each
  /// reconcile so views can observe it; the host itself is not observable.
  var liveSessions: Set<TerminalSession.ID> = []
  /// What each running shell last said its title was. Kept apart from the
  /// workspace so a prompt does not re-render the sidebar or schedule a save.
  var sessionTitles: [TerminalSession.ID: String] = [:]
  /// Projects whose directory has gone. Kept in the sidebar, dimmed, rather
  /// than dropped: an unmounted drive should not delete someone's setup.
  var missingProjects: Set<Project.ID> = []
  /// Worktrees whose saved tabs have been given live shells. Empty at launch,
  /// so relaunching with many saved tabs starts nothing; grows as worktrees
  /// are visited and never shrinks while the app runs.
  @ObservationIgnored var warmWorktrees: Set<Worktree.ID> = []

  @ObservationIgnored let store: WorkspaceStore
  @ObservationIgnored let registry: SessionRegistry
  @ObservationIgnored let stateSource: any SessionStateSource
  @ObservationIgnored let notifier: any SessionNotifier
  /// Sessions that came off disk this run. Their agent tabs resume rather
  /// than start afresh; see `prepared`.
  @ObservationIgnored let restoredSessionIDs: Set<TerminalSession.ID>
  @ObservationIgnored var pidWatch: Task<Void, Never>?
  /// How often a Working state's pid is checked. Settable so a test does
  /// not wait the full interval.
  @ObservationIgnored var pidPollInterval: Duration = .seconds(2)
  @ObservationIgnored var reportedMissingAgents: Set<String> = []
  @ObservationIgnored let worktrees: WorktreeCoordinator?
  @ObservationIgnored var pendingSave: Task<Void, Never>?
  /// Set while saves are failing, so the alert is raised once rather than
  /// again after every change until the disk is writable.
  @ObservationIgnored var saveFailureReported = false
  @ObservationIgnored let watcher: any DirectoryWatcher
  @ObservationIgnored var statusPolling: Task<Void, Never>?
  /// One coalesced status refresh per worktree; see `noteActivity`.
  @ObservationIgnored var pendingStatusRefreshes: [Worktree.ID: Task<Void, Never>] = [:]
  /// `git rev-parse --git-common-dir` per project, asked once. The watcher
  /// and the records check below run from it without spawning git.
  @ObservationIgnored var commonGitDirectories: [Project.ID: URL] = [:]
  /// What the last refresh of each project was computed from; see
  /// `refreshWorktreesIfRecordsChanged`.
  @ObservationIgnored var worktreeRecords: [Project.ID: WorktreeRecords] = [:]

  var workspace: Workspace { store.workspace }

  convenience init() {
    let (store, loadError) = WorkspaceStore.restored()
    self.init(
      store: store,
      host: MultiEngineHost(engine: store.workspace.terminalEngine),
      worktrees: try? WorktreeCoordinator(),
      watcher: DispatchDirectoryWatcher(),
      stateSource: SocketStateSource(),
      notifier: UserNotificationNotifier(),
      loadError: loadError
    )
  }

  /// Dependencies are passed in so tests can run the whole model against
  /// recording engines, a fake watcher, a fake channel and no git.
  init(
    store: WorkspaceStore,
    host: MultiEngineHost,
    worktrees: WorktreeCoordinator?,
    watcher: any DirectoryWatcher,
    stateSource: any SessionStateSource = NullStateSource(),
    notifier: any SessionNotifier = NullNotifier(),
    loadError: (any Error)? = nil
  ) {
    self.store = store
    self.host = host
    self.registry = SessionRegistry(store: store, host: host)
    self.worktrees = worktrees
    self.watcher = watcher
    self.stateSource = stateSource
    self.notifier = notifier
    self.restoredSessionIDs = Set(store.workspace.sessions.map(\.id))

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
    registry.onCommandFinished = { [weak self] id, code in
      self?.noteCommandFinished(in: id, exitCode: code)
    }
    registry.onRetitle = { [weak self] id, title in self?.noteTitle(title, of: id) }
    registry.onLiveSessionsChanged = { [weak self] in
      guard let self else { return }
      let live = registry.liveSessionIDs
      if live != liveSessions { liveSessions = live }
      sessionTitles = sessionTitles.filter { live.contains($0.key) }
      pruneStates()
      // A shell exiting can bring another tab into view; it is being looked
      // at now, whatever happened in it before.
      markShownTabSeen()
    }
    stateSource.onReport = { [weak self] report in self?.apply(report) }
    notifier.onActivate = { [weak self] key in self?.reveal(key) }
    watcher.onChange = { [weak self] in Task { await self?.refreshWorktreesIfRecordsChanged() } }
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
    startStateSource()
    do {
      try HelperInstaller.refreshLink()
      try ShellIntegration.refresh()
    } catch {
      report(error)
    }
    await refreshAll()
    sync()
    startStatusPolling()
    await refreshLoginEnvironment()
  }

  func refreshAll() async {
    await refreshWorktreesIfRecordsChanged()
    await refreshStatuses()
  }

  /// What a watcher tick and a return to the foreground run. The watched
  /// directories also hold each linked worktree's `index`, which `git status`
  /// rewrites, so most ticks mean nothing; comparing the files `git worktree
  /// list` is derived from tells those apart from a real change without
  /// spawning git. A project with no records yet, or none git can find, is
  /// refreshed in full; that path also notices a repository that has gone.
  func refreshWorktreesIfRecordsChanged() async {
    for project in workspace.projects {
      if let common = await commonGitDirectory(of: project),
        let known = worktreeRecords[project.id],
        await Self.offMain({ WorktreeRecords.read(commonDirectory: common) }) == known
      {
        continue
      }
      await refresh(project)
    }
    await rearmWatcher()
  }

  /// Re-read after every refresh: a new worktree adds a directory that must
  /// itself be watched for branch changes.
  func rearmWatcher() async {
    var directories: [URL] = []
    for project in workspace.projects {
      guard let common = await commonGitDirectory(of: project) else { continue }
      directories += await Self.offMain { WorktreeCoordinator.directoriesToWatch(in: common) }
    }
    watcher.watch(directories)
  }

  func commonGitDirectory(of project: Project) async -> URL? {
    if let cached = commonGitDirectories[project.id] { return cached }
    guard let worktrees, let common = try? await worktrees.commonGitDirectory(project) else {
      return nil
    }
    commonGitDirectories[project.id] = common
    return common
  }
}

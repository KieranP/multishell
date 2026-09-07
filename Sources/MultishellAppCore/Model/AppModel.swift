import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import Observation

/// Wires the core to a GUI: owns the store, the terminal host and the git
/// coordinator, and turns view actions into store mutations.
///
/// Views read `workspace` and call these methods. They never touch the host,
/// the registry or git directly. `Surface` is the platform's view type, the
/// one thing about a frontend the model has to name; everything else it
/// needs from the desktop comes through `Platform`.
@Observable
@MainActor
public final class AppModel<Surface> {
  let host: MultiEngineHost<Surface>
  public let platform: any Platform

  public var presentedError: PresentedError?
  public var newWorktreeRequest: NewWorktreeRequest?
  /// A removal waiting on the confirmation dialog.
  public var pendingRemoval: PendingWorktreeRemoval?
  /// Which stage a create is in while the sheet still waits on it: the
  /// pre-create hook and `git worktree add`. `nil` when none is running.
  public var worktreeCreationStep: WorktreeCreationStep?
  /// The create or remove running on each worktree, shown in its detail
  /// pane in place of the terminals; see `WorktreeOperations` for who owns
  /// an entry.
  public var worktreeOperations = WorktreeOperations()
  /// The worktree whose sidebar row is showing its name field, or `nil`
  /// when none is. Runtime state, so the menu that starts a rename and the
  /// row that draws the field need not know about each other.
  public var renamingWorktreeID: Worktree.ID?
  /// The post-create hooks still running, so a test can await one.
  @ObservationIgnored public var postCreateHooks: [Worktree.ID: Task<Void, Never>] = [:]
  /// The stop handle for the hook running on each worktree, behind the
  /// pane's Stop Hook.
  @ObservationIgnored var hookStoppers: [Worktree.ID: ProcessStopper] = [:]
  /// The stop handle for the pre-create hook under the sheet.
  @ObservationIgnored var creationStopper: ProcessStopper?
  /// What each project's `.multishell.json` says, re-read on every refresh.
  /// Absent for a project without one.
  public var sharedSettings: [Project.ID: SharedProjectSettings] = [:]
  /// The date each project's file had when it was last read, so a tick can
  /// tell an edited file from an untouched one with a stat rather than a
  /// read; `.distantPast` for a project that has none. Absent until the
  /// first read, which is what tells a change apart from a first sight.
  @ObservationIgnored var sharedSettingsStamps: [Project.ID: Date] = [:]
  /// Why a project's `.multishell.json` could not be read, for its Hooks tab.
  public var sharedSettingsProblems: [Project.ID: String] = [:]
  /// The trust question about one project's shared hooks, waiting on its
  /// dialog.
  public var pendingSharedHooksTrust: PendingSharedHooksTrust?
  /// A project removal waiting on its dialog, in whichever window asked.
  public var pendingProjectRemoval: PendingProjectRemoval?
  /// A pane or tab close waiting on it, because an agent there is working.
  public var pendingClose: PendingClose?
  /// Which project the settings window shows.
  public var settingsProjectID: Project.ID?
  /// What each live terminal is doing, from the engine and from reports over
  /// the socket; see `SessionStates` for who clears what.
  public var sessionStates = SessionStates()
  /// The environment of the user's interactive login shell, once captured.
  /// `nil` until the shell has answered.
  public var loginEnvironment: LoginShellEnvironment?
  /// Which catalogue agents that environment's PATH has.
  public var agentDetection = AgentDetection.empty
  /// Which shells the machine has, from `/etc/shells` and that PATH.
  public var shellDetection = ShellDetection.empty
  /// Which catalogue editors are installed, by application id or shim.
  public var editorDetection = EditorDetection.empty
  public var claudeHooksInstalled = false
  public var commandLineToolInstalled = false
  public var themes: [Theme] = Theme.builtins
  /// `git status` per worktree. Runtime only; see `WorktreeStatus`.
  public var statuses: [Worktree.ID: WorktreeStatus] = [:]
  /// Whether each worktree's branch has already landed on its project's
  /// default branch. Runtime only; see `WorktreeMergeState`.
  public var mergeStates: [Worktree.ID: WorktreeMergeState] = [:]
  /// The branch each project's merges are measured against, `origin/main`
  /// and the like. Absent for a project with none to measure against.
  public var mergeBases: [Project.ID: DefaultBranch] = [:]
  /// Projects with a `git fetch` running, which the sidebar shows and a
  /// second Fetch waits for. Runtime state, like the statuses beside it.
  public var fetchingProjects: Set<Project.ID> = []
  /// What each worktree's merge verdict was computed from, so a refresh
  /// that finds nothing moved spawns no git; see `MergeCheck`.
  @ObservationIgnored var mergeChecks: [Worktree.ID: MergeCheck] = [:]
  /// Sessions with a running shell, mirrored from the host after each
  /// reconcile so views can observe it; the host itself is not observable.
  public var liveSessions: Set<TerminalSession.ID> = []
  /// What each running shell last said its title was. Kept apart from the
  /// workspace so a prompt does not re-render the sidebar or schedule a save.
  public var sessionTitles: [TerminalSession.ID: String] = [:]
  /// Which agent last reported in each session; see `ReportedAgent`. What
  /// a file dropped on a pane is written as reads this, so an agent started
  /// by hand is addressed as itself. Runtime state, like the titles above.
  @ObservationIgnored var reportedAgents: [TerminalSession.ID: ReportedAgent] = [:]
  /// Projects whose directory has gone. Kept in the sidebar, dimmed, rather
  /// than dropped: an unmounted drive should not delete someone's setup.
  public var missingProjects: Set<Project.ID> = []
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
  @ObservationIgnored public var pidPollInterval: Duration = .seconds(2)
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

  public var workspace: Workspace { store.workspace }

  /// Dependencies are passed in so tests can run the whole model against
  /// recording engines, a fake watcher, a fake channel, a bare desktop and
  /// no git. The platform GUI passes its real ones.
  public init(
    store: WorkspaceStore,
    host: MultiEngineHost<Surface>,
    worktrees: WorktreeCoordinator?,
    watcher: any DirectoryWatcher,
    platform: any Platform = NullPlatform(),
    stateSource: any SessionStateSource = NullStateSource(),
    notifier: any SessionNotifier = NullNotifier(),
    loadError: (any Error)? = nil
  ) {
    self.store = store
    self.host = host
    self.platform = platform
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
    platform.onDidBecomeActive = { [weak self] in Task { await self?.refreshAll() } }

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
      reportedAgents = reportedAgents.filter { live.contains($0.key) }
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

  /// The view a session draws into, from whichever engine opened it. The
  /// one thing a view takes from the host, so the host itself stays out of
  /// the views' reach.
  public func surface(for id: TerminalSession.ID) -> Surface? {
    host.view(for: id)
  }

  /// The user clicked into a surface's frame: the engine makes it first
  /// responder and reports the focus back through the registry.
  public func focusSurface(_ id: TerminalSession.ID) {
    host.focus(id)
  }

  /// Shells actually running, as opposed to saved tabs waiting to be opened.
  public var liveTerminalCount: Int { liveSessions.count }

  public func liveTerminalCount(in worktree: Worktree.ID) -> Int {
    workspace.sessions(in: worktree).filter { liveSessions.contains($0.id) }.count
  }

  public var currentTheme: Theme {
    workspace.appearance.theme(from: themes)
  }

  /// Restores the sidebar from disk, then asks git what each project
  /// actually has. Terminals are not restored; only the tree is.
  public func start() async {
    startStateSource()
    do {
      try HelperLink.refresh(to: platform.bundledHelper)
      try ShellIntegration.refresh()
    } catch {
      report(error)
    }
    await refreshAll()
    sync()
    startStatusPolling()
    await refreshLoginEnvironment()
  }

  public func refreshAll() async {
    await refreshWorktreesIfRecordsChanged()
    await refreshStatuses()
    await refreshMergeStates()
  }

  /// What a watcher tick and a return to the foreground run. The watched
  /// directories also hold each linked worktree's `index`, which `git status`
  /// rewrites, so most ticks mean nothing; comparing the files `git worktree
  /// list` is derived from tells those apart from a real change without
  /// spawning git. A project with no records yet, or none git can find, is
  /// refreshed in full; that path also notices a repository that has gone.
  /// A tick where nothing moved still stats each `.multishell.json`, since
  /// a full refresh is the only other thing that reads one and a file
  /// edited by hand moves no record.
  public func refreshWorktreesIfRecordsChanged() async {
    for project in workspace.projects {
      if let common = await commonGitDirectory(of: project),
        let known = worktreeRecords[project.id],
        await Self.offMain({ WorktreeRecords.read(commonDirectory: common) }) == known
      {
        await refreshSharedSettingsIfChanged(project)
        continue
      }
      await refresh(project)
    }
    await rearmWatcher()
  }

  /// Re-read after every refresh: a new worktree adds a directory that must
  /// itself be watched for branch changes.
  public func rearmWatcher() async {
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

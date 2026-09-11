import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import Observation

/// Wires the core to a GUI and turns view actions into store mutations;
/// see docs/design/architecture.md.
@Observable
@MainActor
public final class AppModel<Surface> {
  // Each property left its own: bundling the observed ones into structs
  // coarsens what `@Observable` tracks.

  // MARK: - Dependencies

  let host: MultiEngineHost<Surface>
  public let platform: any Platform
  @ObservationIgnored let store: WorkspaceStore
  @ObservationIgnored let registry: SessionRegistry
  @ObservationIgnored let stateSource: any SessionStateSource
  @ObservationIgnored let notifier: any SessionNotifier
  @ObservationIgnored let watcher: any DirectoryWatcher
  /// `var`: git is looked up again once the login shell's PATH is known, which
  /// is after this is built. See `refreshLoginEnvironment`.
  @ObservationIgnored var worktrees: WorktreeCoordinator?
  /// Sessions that came off disk this run. Their agent tabs resume rather
  /// than start afresh; see `prepared`.
  @ObservationIgnored let restoredSessionIDs: Set<TerminalSession.ID>

  // MARK: - Waiting on the user

  public var presentedError: PresentedError?
  public var newWorktreeRequest: NewWorktreeRequest?
  /// A removal waiting on the confirmation dialog.
  public var pendingRemoval: PendingWorktreeRemoval?
  /// The trust question about one project's shared hooks, waiting on its
  /// dialog.
  public var pendingSharedHooksTrust: PendingSharedHooksTrust?
  /// A project removal waiting on its dialog, in whichever window asked.
  public var pendingProjectRemoval: PendingProjectRemoval?
  /// A pane or tab close waiting on it, because an agent there is working.
  public var pendingClose: PendingClose?
  /// Which project the settings window shows.
  public var settingsProjectID: Project.ID?
  /// The worktree showing its name field. Runtime state, so the menu that
  /// starts a rename and the row that draws it need not know each other.
  public var renamingWorktreeID: Worktree.ID?

  // MARK: - The Agents board

  /// Whether the board fills the detail area. Runtime state; set through
  /// `showAgentBoard` and `hideAgentBoard`, which do the seen-clearing.
  public internal(set) var showsAgentBoard = false
  /// Whether the board shows every terminal or only agent panes. Here and not
  /// in the view, the Dock badge reading the same filter.
  public internal(set) var showsAllTerminals = false
  /// What the badge was last set to, so it is written only when it changes.
  @ObservationIgnored var badgedWaitingCount = 0

  // MARK: - Creates and removes under way

  /// Which stage a create is in while the sheet still waits on it: the
  /// pre-create hook and `git worktree add`. `nil` when none is running.
  public var worktreeCreationStep: WorktreeCreationStep?
  /// The create or remove running on each worktree, shown in its detail pane;
  /// see `WorktreeOperations` for who owns an entry.
  public var worktreeOperations = WorktreeOperations()
  /// The file lists and post-create hook still running on each worktree,
  /// as one task, so a test can await it.
  @ObservationIgnored public var worktreeSetups: [Worktree.ID: Task<Void, Never>] = [:]
  /// The stop handle for the stage running on each worktree, behind the
  /// pane's Cancel: a hook by signal, a file list between files.
  @ObservationIgnored var stageStoppers: [Worktree.ID: ProcessStopper] = [:]
  /// The stop handle for the pre-create hook under the sheet.
  @ObservationIgnored var creationStopper: ProcessStopper?

  // MARK: - Terminals

  /// Sessions with a running shell, mirrored from the host after each
  /// reconcile so views can observe it; the host itself is not observable.
  public var liveSessions: Set<TerminalSession.ID> = []
  /// What each running shell last said its title was. Kept apart from the
  /// workspace so a prompt does not re-render the sidebar or schedule a save.
  public var sessionTitles: [TerminalSession.ID: String] = [:]
  /// What each live terminal is doing, from the engine and from reports over
  /// the socket; see `SessionStates` for who clears what.
  public var sessionStates = SessionStates()
  /// Which agent last reported in each session, so a dropped file and the
  /// board both know who is at the prompt; see `ReportedAgent`.
  public internal(set) var reportedAgents: [TerminalSession.ID: ReportedAgent] = [:]
  /// Keys whose banner may still be on screen, so one is taken back only
  /// where there is one to take back. A key leaves as its banner does.
  @ObservationIgnored var notifiedKeys: Set<SessionStates.Key> = []
  /// Worktrees whose saved tabs have been given live shells. Empty at launch,
  /// so a relaunch starts nothing; never shrinks while the app runs.
  @ObservationIgnored var warmWorktrees: Set<Worktree.ID> = []
  @ObservationIgnored var pidWatch: Task<Void, Never>?
  /// How often a Working state's pid is checked. Settable so a test does
  /// not wait the full interval.
  @ObservationIgnored public var pidPollInterval: Duration = .seconds(2)

  // MARK: - What the machine has

  /// The environment of the user's interactive login shell, once captured.
  /// `nil` until the shell has answered.
  public var loginEnvironment: LoginShellEnvironment?
  /// Which catalogue agents that environment's PATH has.
  public var agentDetection = AgentDetection.empty
  /// Which shells the machine has, from `/etc/shells` and that PATH.
  public var shellDetection = ShellDetection.empty
  /// Which catalogue editors are installed, by application id or shim.
  public var editorDetection = EditorDetection.empty
  /// Which agents' hooks are in place, by catalogue id. Read from disk on
  /// demand by `refreshAgentStatus`, not observed.
  public var installedAgentHooks: Set<String> = []
  public var commandLineToolInstalled = false
  /// What the notification centre has been told about this app. The system's
  /// answer, not the workspace's, and changeable while the app runs.
  public internal(set) var notificationAuthorization = NotificationAuthorization.notAsked
  public var themes: [Theme] = Theme.builtins
  @ObservationIgnored var reportedMissingAgents: Set<String> = []

  // MARK: - What git says

  /// `git status` per worktree. Runtime only; see `WorktreeStatus`.
  public var statuses: [Worktree.ID: WorktreeStatus] = [:]
  /// Whether each worktree's branch has already landed on its project's
  /// default branch. Runtime only; see `WorktreeMergeState`.
  public var mergeStates: [Worktree.ID: WorktreeMergeState] = [:]
  /// The branch each project's merges are measured against, `origin/main`
  /// and the like. Absent for a project with none to measure against.
  public var mergeBases: [Project.ID: DefaultBranch] = [:]
  /// When each worktree's branch was last committed to. Runtime only: the
  /// workspace must not be rewritten because someone committed.
  public var lastCommits: [Worktree.ID: Date] = [:]
  /// Projects with a `git fetch` running, which the sidebar shows and a
  /// second Fetch waits for. Runtime state, like the statuses beside it.
  public var fetchingProjects: Set<Project.ID> = []
  /// Projects whose directory has gone. Kept in the sidebar, dimmed, rather
  /// than dropped: an unmounted drive should not delete someone's setup.
  public var missingProjects: Set<Project.ID> = []
  /// What each worktree's merge verdict was computed from, so a refresh
  /// that finds nothing moved spawns no git; see `MergeCheck`.
  @ObservationIgnored var mergeChecks: [Worktree.ID: MergeCheck] = [:]
  /// `git rev-parse --git-common-dir` per project, asked once. The watcher
  /// and the records check run from it without spawning git.
  @ObservationIgnored var commonGitDirectories: [Project.ID: URL] = [:]
  /// What the last refresh of each project was computed from; see
  /// `refreshWorktreesIfRecordsChanged`.
  @ObservationIgnored var worktreeRecords: [Project.ID: WorktreeRecords] = [:]
  @ObservationIgnored var statusPolling: Task<Void, Never>?
  /// One coalesced status refresh per worktree; see `noteActivity`.
  @ObservationIgnored var pendingStatusRefreshes: [Worktree.ID: Task<Void, Never>] = [:]

  // MARK: - What the repository says

  /// What each project's `.multishell.json` says, the date it had when it
  /// was read, and why it would not parse; see `SharedSettingsCache`.
  public var sharedSettings = SharedSettingsCache()

  // MARK: - Saving

  @ObservationIgnored var pendingSave: Task<Void, Never>?
  /// Set while saves are failing, so the alert is raised once rather than
  /// again after every change until the disk is writable.
  @ObservationIgnored var saveFailureReported = false

  public var workspace: Workspace { store.workspace }

  /// Dependencies are passed in so tests run the whole model against fakes.
  /// The platform GUI passes its real ones.
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
    // Said on the process's PATH alone. `refreshLoginEnvironment` looks again
    // on the login shell's and takes this back if it finds git there.
    if let loadError {
      report(loadError)
    } else if worktrees == nil {
      report(GitUnavailable())
    }

    // Nothing is selected at launch, so no shell starts until the user picks
    // a worktree. Saved tabs stay saved and open with that first click.
    store.selectWorktree(nil)

    // Statuses poll only while frontmost, so a return would show badges five
    // seconds stale. The permission is read back for the same reason.
    platform.onDidBecomeActive = { [weak self] in
      Task { await self?.refreshAll() }
      self?.refreshNotificationAuthorization()
      // Coming back is seeing what is on screen: a Done raised while the
      // user was elsewhere clears now, and its banner goes with it.
      self?.markShownTabSeen()
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
      // Assigned only when it drops one: the board and the sidebar entry are
      // drawn from this, and an idle write renders both.
      let remaining = reportedAgents.filter { live.contains($0.key) }
      if remaining.count != reportedAgents.count { reportedAgents = remaining }
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

  /// The view a session draws into, from whichever engine opened it: the one
  /// thing a view takes from the host.
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
    // Outside the refreshes, which throw: this sweep is all that bounds the
    // drops directory.
    DroppedFiles.sweep()
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

  /// What a watcher tick and a return to the foreground run. Most ticks mean
  /// nothing, so the worktree records are compared before git is spawned.
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

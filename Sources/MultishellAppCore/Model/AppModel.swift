import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import Observation

/// Wires the core to a GUI and turns view actions into store mutations;
/// see Docs/design/architecture.md.
@Observable
@MainActor
public final class AppModel<Surface> {
  // Each property left its own: bundling the observed ones into structs
  // coarsens what `@Observable` tracks.

  let host: any TerminalSurfaceHost<Surface>
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

  public var presentedError: PresentedError?
  public var newWorktreeRequest: NewWorktreeRequest?
  /// A removal waiting on the confirmation dialog.
  public var pendingRemoval: PendingWorktreeRemoval?
  /// The trust question about one project's shared hooks, waiting on its
  /// dialog.
  public var pendingSharedSettingsTrust: PendingSharedSettingsTrust?
  /// A project removal waiting on its dialog, in whichever window asked.
  public var pendingProjectRemoval: PendingProjectRemoval?
  /// A pane or tab close waiting on it, because an agent there is working.
  public var pendingClose: PendingClose?
  /// Held here, not by the sidebar, because the poll reads the rows it opens.
  public var sidebarFilterText = "" {
    didSet {
      guard sidebarFilterText != oldValue else { return }
      scheduleRevealedRowsRead(from: oldValue)
      if !sidebarFilterText.isEmpty { showsSidebarFilter = true }
    }
  }
  /// Up whenever there is text, and down only through `setSidebarFilterOpen`,
  /// so emptying the field never takes the keyboard away with it.
  public internal(set) var showsSidebarFilter = false
  /// Which project the settings window shows.
  public var settingsProjectID: Project.ID?
  /// The worktree showing its name field. Runtime state, so the menu that
  /// starts a rename and the row that draws it need not know each other.
  public var renamingWorktreeID: Worktree.ID?
  /// The tab whose strip shows a name field, for the same reason the worktree
  /// above has one: a commit arriving after the edit ended must be ignored.
  public var renamingTabID: TerminalTab.ID?
  /// The panes with a find bar up, each pane's its own; see `showFind`.
  /// Runtime state, dropped with the session.
  public internal(set) var findingSessionIDs: Set<TerminalSession.ID> = []
  /// Each pane's needle, kept across closes so Cmd+F then Return repeats the
  /// last search there; read through `findText(of:)`.
  var findNeedles: [TerminalSession.ID: String] = [:]
  /// Panes whose bar has a Cmd+F to answer, claimed through `takeFindFieldRequest`;
  /// a bar a worktree switch brings back has none. See terminals.md.
  public internal(set) var findFieldRequests: Set<TerminalSession.ID> = []
  /// Panes whose search has a selected match: a step has gone since the needle.
  /// The first step after a needle lands nearest the prompt; terminals.md.
  var findSelections: Set<TerminalSession.ID> = []
  /// The pane whose bar's field has the keyboard, which the menu's find items
  /// act on ahead of the focused pane, a field taking no store focus.
  public internal(set) var findFieldPane: TerminalSession.ID?

  /// What a tab drag is doing. Here, not in the column tree that draws it,
  /// because a sidebar row takes a drop too and could not reach a `@State`.
  public var tabDrag = TabDragState()
  /// Ends a drag whose button was rebuilt under it; see `tabDragSourceLeft`.
  @ObservationIgnored var tabDragReleaseWatch: Task<Void, Never>?
  /// The project dragged in the sidebar. Here, not in a `@State`, so the
  /// release watch can end it; see `projectDragSourceLeft`.
  public internal(set) var draggingProject: Project.ID?
  @ObservationIgnored var projectDragReleaseWatch: Task<Void, Never>?

  /// Whether the board fills the detail area. Runtime state; set through
  /// `showAgentBoard` and `hideAgentBoard`, which do the seen-clearing.
  public internal(set) var showsAgentBoard = false
  /// Whether the board shows every terminal or only agent panes. Here and not
  /// in the view, the Dock badge reading the same filter.
  public internal(set) var showsAllTerminals = false
  /// What the badge was last set to, so it is written only when it changes.
  @ObservationIgnored var badgedWaitingCount = 0
  /// The board as last built; see `agentBoard`. Bumping the generation is
  /// what tells a view holding it that it went stale.
  @ObservationIgnored var cachedAgentBoard: AgentBoard?
  var agentBoardGeneration = 0
  /// How many times the board was built, for the tests.
  @ObservationIgnored var agentBoardBuilds = 0

  /// Which stage a create is in while the sheet still waits on it: the
  /// pre-create hook and `git worktree add`. `nil` when none is running.
  public var worktreeCreationStep: WorktreeCreationStep?
  /// The create or remove running on each worktree, shown in its detail pane;
  /// see `WorktreeOperations` for who owns an entry.
  public var worktreeOperations = WorktreeOperations()
  /// The work building a worktree. Not observed: the pane draws from
  /// `worktreeOperations` beside it.
  @ObservationIgnored var workInFlight = WorktreeWorkInFlight()

  /// Sessions with a running shell, mirrored from the host after each
  /// reconcile so views can observe it; the host itself is not observable.
  public var liveSessions: Set<TerminalSession.ID> = []
  /// What each running shell last said its title was. Kept apart from the
  /// workspace so a prompt does not re-render the sidebar or schedule a save.
  var sessionTitles: [TerminalSession.ID: String] = [:]
  /// What each live terminal is doing, from the engine and from reports over
  /// the socket; see `SessionStates` for who clears what.
  var sessionStates = SessionStates()
  /// Which agent last reported in each session, so a dropped file and the
  /// board both know who is at the prompt; see `ReportedAgent`.
  public internal(set) var reportedAgents: [TerminalSession.ID: ReportedAgent] = [:]
  /// The agent a shell said it was starting, kept only while that command
  /// runs. What marks a pane where nobody installed the agent's hooks.
  public internal(set) var commandAgents: [TerminalSession.ID: String] = [:]
  /// Keys whose banner may still be on screen, so one is taken back only
  /// where there is one to take back. A key leaves as its banner does.
  @ObservationIgnored var notifiedKeys: Set<SessionStates.Key> = []
  /// Worktrees whose saved tabs have been given live shells. Empty at launch,
  /// so a relaunch starts nothing; shrinks only as worktrees are forgotten.
  @ObservationIgnored var warmWorktrees: Set<Worktree.ID> = []
  /// Each project's exports of its repository's file, landing in the order
  /// they were asked.
  @ObservationIgnored var sharedSettingsWrites: [Project.ID: SaveOrder] = [:]
  /// Settable so a test stands in a mount that never answers.
  @ObservationIgnored var directoryProbe = DirectoryProbe()
  @ObservationIgnored var pidWatch: Task<Void, Never>?
  /// How often a Working state's pid is checked. Settable so a test does
  /// not wait the full interval.
  @ObservationIgnored var pidPollInterval: Duration = .seconds(2)
  /// How long a resuming agent has to report its woken turn; see agents.md.
  @ObservationIgnored var resumeGrace: Duration = .seconds(15)
  @ObservationIgnored var resumeDeadlines: [SessionStates.Key: Task<Void, Never>] = [:]
  /// Runs the user's login shell for its environment. Settable so a test
  /// hands in a PATH of its own rather than reading the developer's machine.
  @ObservationIgnored var captureLoginEnvironment: @Sendable () async -> LoginShellEnvironment = {
    await LoginShellEnvironment.capture()
  }
  /// A harness stands in for both, the real ones writing the account's own files.
  @ObservationIgnored var refreshLaunchFiles: @Sendable (_ helper: URL?) -> (any Error)? =
    LaunchFiles.refresh
  @ObservationIgnored var sweepDroppedFiles: @Sendable () -> Void = { DroppedFiles.sweep() }

  /// The environment of the user's interactive login shell, once captured.
  /// `nil` until the shell has answered and its PATH has been scanned.
  public var loginEnvironment: LoginShellEnvironment?
  /// Which catalogue agents that environment's PATH has.
  public var agentDetection = AgentDetection.empty {
    didSet { refreshInstalledAgents() }
  }
  /// The agents a New Tab menu lists, held rather than worked out: a strip's
  /// body reads it on every render. Rebuilt by `refreshInstalledAgents`.
  public internal(set) var installedAgentIDs: [String] = []
  /// Which shells the machine has, from `/etc/shells` and that PATH.
  public var shellDetection = ShellDetection.empty
  /// Which catalogue editors are installed, by application id or shim.
  public var editorDetection = EditorDetection.empty
  /// Which agents' hooks are in place, by catalogue id. Read from disk on
  /// demand by `refreshAgentStatus`, not observed.
  var installedAgentHooks: Set<String> = []
  /// Installed, but not what this build writes.
  var staleAgentHooks: Set<String> = []
  public var commandLineToolInstalled = false
  /// What the notification centre has been told about this app. The system's
  /// answer, not the workspace's, and changeable while the app runs.
  public internal(set) var notificationAuthorization = NotificationAuthorization.notAsked
  public var themes: [Theme] = Theme.builtins
  @ObservationIgnored var reportedMissingAgents: Set<String> = []

  /// `git status` per worktree. Runtime only; see `WorktreeStatus`.
  public var statuses: [Worktree.ID: WorktreeStatus] = [:]
  /// Whether each worktree's branch has already landed on its project's
  /// default branch. Runtime only; see `WorktreeMergeState`.
  var mergeStates: [Worktree.ID: WorktreeMergeState] = [:]
  /// The branch each project's merges are measured against, `origin/main`
  /// and the like. Absent for a project with none to measure against.
  var mergeBases: [Project.ID: DefaultBranch] = [:]
  /// When each worktree's branch was last committed to. Runtime only: the
  /// workspace must not be rewritten because someone committed.
  var lastCommits: [Worktree.ID: Date] = [:]
  /// Projects with a `git fetch` running, which the sidebar shows and a
  /// second Fetch waits for. Runtime state, like the statuses beside it.
  var fetchingProjects: Set<Project.ID> = []
  /// Projects whose directory has gone. Kept in the sidebar, dimmed, rather
  /// than dropped: an unmounted drive should not delete someone's setup.
  public var missingProjects: Set<Project.ID> = []
  /// What each worktree's merge verdict was computed from, so a refresh
  /// that finds nothing moved spawns no git; see `MergeCheck`.
  @ObservationIgnored var mergeChecks: [Worktree.ID: MergeCheck] = [:]
  /// What each verdict cost, which spreads a re-ask of every branch over
  /// several rounds; a test sets `budget` to see them spread.
  @ObservationIgnored var mergeReads = MergeReadLog()
  /// Each worktree's path with its symlinks resolved, for placing a report
  /// that names only a directory. Stale only if a link on the way is repointed.
  @ObservationIgnored var resolvedWorktreePaths: [Worktree.ID: [String]] = [:]
  /// `git rev-parse --git-common-dir` per project, asked once. The watcher
  /// and the records check run from it without spawning git.
  @ObservationIgnored var commonGitDirectories: [Project.ID: URL] = [:]
  /// Written from the sidebar's body, so not observed: a write there would
  /// invalidate the body writing it.
  @ObservationIgnored var worktreeOrders = WorktreeOrderMemo()
  /// What the last refresh of each project was computed from; see
  /// `refreshWorktreesIfRecordsChanged`.
  @ObservationIgnored var worktreeRecords: [Project.ID: WorktreeRecords] = [:]
  @ObservationIgnored var statusPolling: Task<Void, Never>?
  /// When each worktree's status was last read and how often it is read; a
  /// test reading right after a change sets `pace` to `.unpaced`.
  @ObservationIgnored var statusReads = StatusReadLog()
  /// One coalesced status refresh per worktree; see `noteActivity`.
  @ObservationIgnored var pendingStatusRefreshes: [Worktree.ID: Task<Void, Never>] = [:]
  /// The read after the filter text changes, one per pause in typing, and
  /// the rows the poll kept reading through every keystroke of that burst.
  @ObservationIgnored var pendingRevealedRowsRead:
    (polledThroughout: Set<Worktree.ID>, task: Task<Void, Never>)?
  /// Worktrees whose removal is reading their status, and the latest asked.
  @ObservationIgnored var removalReads: Set<Worktree.ID> = []
  @ObservationIgnored var latestRemovalRequest: Worktree.ID?

  @ObservationIgnored var pendingSave: Task<Void, Never>?
  @ObservationIgnored var autosave: Task<Void, Never>?
  /// Set where another copy holds the socket: two copies autosaving one file
  /// leave the last writer's, so this one writes nothing; see state-and-store.md.
  @ObservationIgnored var yieldingToRunningInstance = false
  /// Set while saves are failing, so the alert is raised once rather than
  /// again after every change until the disk is writable.
  @ObservationIgnored var saveFailureReported = false

  public var workspace: Workspace { store.workspace }

  /// Dependencies are passed in so tests run the whole model against fakes.
  /// The platform GUI passes its real ones.
  public init(
    store: WorkspaceStore,
    host: any TerminalSurfaceHost<Surface>,
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
    refreshInstalledAgents()
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
      // Coming back is seeing the focused pane: a Done raised there while
      // the user was elsewhere clears now, and its banner goes with it.
      self?.markFocusedPaneSeen()
    }

    registry.onActivity = { [weak self] id in self?.noteActivity(in: id) }
    registry.onCommandFinished = { [weak self] id, code in
      self?.noteCommandFinished(in: id, exitCode: code)
    }
    registry.onRetitle = { [weak self] id, title in self?.noteTitle(title, of: id) }
    // A click into a pane is looking at it: seen is the pane with the
    // keyboard, and a click is how the keyboard moves without a reconcile.
    registry.onFocus = { [weak self] _ in self?.markFocusedPaneSeen() }
    registry.onLiveSessionsChanged = { [weak self] in
      guard let self else { return }
      let live = registry.liveSessionIDs
      setIfChanged(\.liveSessions, live)
      setIfChanged(\.sessionTitles, sessionTitles.filter { live.contains($0.key) })
      setIfChanged(\.reportedAgents, reportedAgents.filter { live.contains($0.key) })
      setIfChanged(\.commandAgents, commandAgents.filter { live.contains($0.key) })
      pruneStates()
      pruneFind()
      // A shell exiting can bring another pane the keyboard; it is being
      // looked at now, whatever happened in it before.
      markFocusedPaneSeen()
    }
    stateSource.onReport = { [weak self] report in self?.apply(report) }
    notifier.onActivate = { [weak self] key in self?.reveal(key) }
    watcher.onChange = { [weak self] changed in
      Task { await self?.refreshWorktreesIfRecordsChanged(under: changed) }
    }
    observeForAutosave()
  }

  deinit {
    autosave?.cancel()
    tabDragReleaseWatch?.cancel()
    projectDragReleaseWatch?.cancel()
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
    guard startStateSource() else { return }
    host.claimSharedFiles()
    // On the main actor, before `start` first yields, so no tab can open ahead.
    if let failure = refreshLaunchFiles(platform.bundledHelper) { report(failure) }
    // All that bounds the drops directory; no terminal waits on it.
    let sweep = sweepDroppedFiles
    Task { await Self.offMain(sweep) }
    await refreshAll()
    reconcileSessions(takingFocus: true)
    startStatusPolling()
    await refreshLoginEnvironment()
  }
}

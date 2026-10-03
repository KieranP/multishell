import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// Wires the core to a GUI and turns view actions into store mutations;
/// see Docs/design/architecture.md.
@Observable
@MainActor
public final class AppModel<Surface> {
  // Each property left its own: bundling the observed ones into structs
  // coarsens what `@Observable` tracks.

  let host: any TerminalSurfaceHost<Surface>
  let platform: any Platform
  @ObservationIgnored let store: WorkspaceStore
  @ObservationIgnored let reconciler: SessionReconciler
  @ObservationIgnored let stateSource: any SessionStateSource
  @ObservationIgnored let notifier: any SessionNotifier
  @ObservationIgnored let watcher: any DirectoryWatcher
  /// `var`: git is looked up again once the login shell's PATH is known, which
  /// is after this is built. See `refreshLoginEnvironment`.
  @ObservationIgnored var coordinator: WorktreeCoordinator?
  /// Sessions that came off disk this run. Their agent tabs resume rather
  /// than start afresh; see `preparedForLaunch`.
  @ObservationIgnored let restoredSessionIDs: Set<TerminalSession.ID>

  var presentedError: PresentedError?
  public var newWorktreeRequest: NewWorktreeRequest?
  public internal(set) var pendingWorktreeRemoval: PendingWorktreeRemoval?
  public internal(set) var pendingSharedSettingsTrust: PendingSharedSettingsTrust?
  /// A project removal waiting on its dialog, in whichever window asked.
  var pendingProjectRemoval: PendingProjectRemoval?
  /// A pane or tab close waiting on it, because an agent there is working.
  public internal(set) var pendingClose: PendingClose?
  /// Held here, not by the sidebar, because the poll reads the rows it opens.
  public var sidebarFilterText = "" {
    didSet {
      guard sidebarFilterText != oldValue else { return }
      let collapsedBefore = projectsCollapsedWhileFiltering
      setIfChanged(\.projectsCollapsedWhileFiltering, [])
      scheduleRevealedRowsRead(from: oldValue, collapsing: collapsedBefore)
      if !sidebarFilterText.isEmpty { showsSidebarFilter = true }
    }
  }
  /// Projects collapsed by their chevron while the filter holds them open.
  /// That lasts until the text changes; the stored flag is left alone.
  var projectsCollapsedWhileFiltering: Set<Project.ID> = []
  /// Up whenever there is text, and down only through `setShowsSidebarFilter`,
  /// so emptying the field never takes the keyboard away with it.
  public internal(set) var showsSidebarFilter = false
  /// The project a menu asked the settings window for; `settingsWindowProjectID`
  /// is the one it shows.
  var requestedSettingsProjectID: Project.ID?
  /// The worktree showing its name field. Runtime state, so the menu that
  /// starts a rename and the row that draws it need not know each other.
  var renamingWorktreeID: Worktree.ID?
  /// The tab whose strip shows a name field; a commit arriving after the edit
  /// ended is ignored.
  public internal(set) var renamingTabID: TerminalTab.ID?
  /// The panes with a find bar up, each pane's its own; see `showFind`.
  /// Runtime state, dropped with the session.
  public internal(set) var findBarSessionIDs: Set<TerminalSession.ID> = []
  /// Each pane's find text, kept across closes so Cmd+F then Return repeats the
  /// last search there; read through `findText(of:)`.
  var findTexts: [TerminalSession.ID: String] = [:]
  /// Panes whose bar has a Cmd+F to answer, claimed through `takeFindFieldRequest`;
  /// a bar a worktree switch brings back has none. See terminals.md.
  public internal(set) var findFieldRequests: Set<TerminalSession.ID> = []
  /// Panes whose search has a selected match: a step has gone since the find text
  /// was set. See `step(_:in:)`.
  var steppedFindSessionIDs: Set<TerminalSession.ID> = []
  /// The pane whose bar's field has the keyboard, which the menu's find items
  /// act on ahead of the focused pane, a field taking no store focus.
  var findFieldSessionID: TerminalSession.ID?

  /// What a tab drag is doing. Here, not in the group tree that draws it,
  /// because a sidebar row takes a drop too and could not reach a `@State`.
  public var tabDrag = TabDragState()
  /// Ends a drag whose button was rebuilt under it; see `tabDragSourceLeft`.
  @ObservationIgnored var tabDragReleaseWatch: Task<Void, Never>?
  /// The project dragged in the sidebar. Here, not in a `@State`, so the
  /// release watch can end it; see `projectDragSourceLeft`.
  public internal(set) var draggedProjectID: Project.ID?
  @ObservationIgnored var projectDragReleaseWatch: Task<Void, Never>?

  /// What covers the selected worktree's terminals. Runtime state; set through
  /// the show methods and `uncoverDetail`, which do the seen-clearing.
  var detailCover: DetailCover?
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

  /// View > Enable Debug Tools. Runtime state, so sampling never outlives
  /// the launch it was turned on in.
  public internal(set) var debugToolsEnabled = false
  /// A sample a second while debug tools are on; see `takeDebugSample`.
  var debugHistory = DebugHistory()
  /// Which processes each pane runs, as of the last sample.
  var debugProcessAttribution = PaneProcessAttribution.empty
  /// What the panel shows while paused, the sampling going on under it.
  var pausedDebugSnapshot: DebugSnapshot?
  @ObservationIgnored var debugSampling: Task<Void, Never>?
  /// Settable so a test can push the tick out of reach and take each sample itself.
  @ObservationIgnored var debugSampleInterval: Duration = .seconds(1)
  @ObservationIgnored var frameRateMeter = FrameRateMeter()
  @ObservationIgnored var cpuUsageMeter = CPUUsageMeter()
  @ObservationIgnored var stateReportsSinceDebugSample = 0
  @ObservationIgnored var lastDebugSampleTaken: ContinuousClock.Instant?
  /// Bumped at each start and stop, so a sample begun before either lands nowhere.
  @ObservationIgnored var debugSamplingGeneration = 0
  /// Reads the kernel's process table; a test stands in a scan of its own.
  @ObservationIgnored var scanDebugProcesses:
    @Sendable (_ appPID: Int32, _ terminalPaths: [TerminalSession.ID: String]) -> DebugProcessScan =
      DebugProcessScan.take

  /// Which stage a create is in while the sheet still waits on it: the
  /// pre-create hook and `git worktree add`. `nil` when none is running.
  public internal(set) var worktreeCreationStep: WorktreeCreationStep?
  /// The create or remove running on each worktree, shown in its detail pane;
  /// see `WorktreeOperations` for who owns an entry.
  public internal(set) var worktreeOperations = WorktreeOperations()
  /// The work building a worktree, and the paths it is building at. Not
  /// observed: the pane draws from `worktreeOperations` beside them.
  @ObservationIgnored var stageHandles = WorktreeStageHandles()
  @ObservationIgnored var pathClaims = WorktreePathClaims()

  /// Sessions with a running shell, mirrored from the host after each
  /// reconcile so views can observe it; the host itself is not observable.
  public internal(set) var liveSessionIDs: Set<TerminalSession.ID> = []
  /// What each running shell last said its title was. Kept apart from the
  /// workspace so a prompt does not re-render the sidebar or schedule a save.
  var sessionTitles: [TerminalSession.ID: String] = [:]
  /// What each live terminal is doing, from the engine and from reports over
  /// the socket; see `SessionStates` for who clears what.
  var sessionStates = SessionStates()
  /// Which agent last reported in each session, so a dropped file and the
  /// board both know who is at the prompt; see `ReportedAgent`.
  var reportedAgents: [TerminalSession.ID: ReportedAgent] = [:]
  /// The agent a shell said it was starting, kept only while that command
  /// runs. What marks a pane where nobody installed the agent's hooks.
  var commandAgentIDs: [TerminalSession.ID: String] = [:]
  /// Keys whose banner may still be on screen, so one is taken back only
  /// where there is one to take back. A key leaves as its banner does.
  @ObservationIgnored var notifiedKeys: Set<SessionStates.Key> = []
  /// Worktrees whose saved tabs have been given live shells. Empty at launch,
  /// so a relaunch starts nothing; shrinks only as worktrees are forgotten.
  @ObservationIgnored var warmWorktrees: Set<Worktree.ID> = []
  /// Each project's exports of its repository's file, landing in the order
  /// they were asked.
  @ObservationIgnored var sharedSettingsExportOrders: [Project.ID: SaveOrder] = [:]
  /// Settable so a test stands in a mount that never answers.
  @ObservationIgnored var directoryProbe = DirectoryProbe()
  @ObservationIgnored var pidWatch: Task<Void, Never>?
  /// How often a Working state's pid is checked. Settable so a test does
  /// not wait the full interval.
  @ObservationIgnored var pidPollInterval: Duration = .seconds(2)
  /// Runs the user's login shell for its environment. Settable so a test
  /// hands in a PATH of its own rather than reading the developer's machine.
  @ObservationIgnored var captureLoginEnvironment: @Sendable () async -> LoginShellEnvironment = {
    await LoginShellEnvironment.capture(shellPath: ShellChoice.loginShellPath())
  }
  /// A harness stands in for both, the real ones writing the account's own files.
  @ObservationIgnored var refreshAppLaunchFiles: @Sendable (_ helper: URL?) throws -> Void =
    AppLaunchFiles.refresh
  @ObservationIgnored var sweepPromisedDropCopies: @Sendable () -> Void = {
    PromisedDropCopies.sweep()
  }

  /// The environment of the user's interactive login shell, once captured.
  /// `nil` until the shell has answered and its PATH has been scanned.
  var loginEnvironment: LoginShellEnvironment?
  /// Which catalogue agents that environment's PATH has.
  public internal(set) var agentDetection = AgentDetection.empty {
    didSet { refreshNewTabAgents() }
  }
  /// The agents a New Tab menu lists, held rather than worked out: a strip's
  /// body reads it on every render. Rebuilt by `refreshNewTabAgents`.
  public internal(set) var newTabAgentIDs: [String] = []
  /// Which shells the machine has, from `/etc/shells` and that PATH.
  public internal(set) var shellDetection = ShellDetection.empty
  /// Which catalogue editors are installed, by application id or shim.
  public internal(set) var editorDetection = EditorDetection.empty
  /// Which agents' hooks are in place, by catalogue id. Read from disk on
  /// demand by `refreshInstallState`, not observed.
  var installedAgentHooks: Set<String> = []
  /// Installed, but not what this build writes.
  var staleAgentHooks: Set<String> = []
  public internal(set) var isCommandLineToolInstalled = false
  /// What the notification centre has been told about this app. The system's
  /// answer, not the workspace's, and changeable while the app runs.
  var notificationAuthorization = NotificationAuthorization.notAsked
  public internal(set) var themes: [Theme] = Theme.builtins
  @ObservationIgnored var alertedMissingAgentIDs: Set<String> = []

  /// `git status` per worktree. Runtime only; see `WorktreeStatus`.
  public internal(set) var statuses: [Worktree.ID: WorktreeStatus] = [:]
  /// Whether each worktree's branch has already landed on its project's
  /// default branch. Runtime only; see `WorktreeMergeState`.
  var mergeStates: [Worktree.ID: WorktreeMergeState] = [:]
  /// The branch each project's merges are measured against, `origin/main`
  /// and the like. Absent for a project with none to measure against.
  var defaultBranches: [Project.ID: DefaultBranch] = [:]
  /// When each worktree's branch was last committed to. Runtime only: the
  /// workspace must not be rewritten because someone committed.
  var lastCommitDates: [Worktree.ID: Date] = [:]
  /// Projects with a `git fetch` running, which the sidebar shows and a
  /// second Fetch waits for. Runtime state, like the statuses beside it.
  var fetchingProjects: Set<Project.ID> = []
  /// Projects whose directory has gone. Kept in the sidebar, dimmed, rather
  /// than dropped: an unmounted drive should not delete someone's setup.
  public internal(set) var missingProjects: Set<Project.ID> = []
  /// What each worktree's merge verdict was computed from, so a refresh
  /// that finds nothing moved spawns no git; see `MergeVerdictBasis`.
  @ObservationIgnored var mergeVerdictBases: [Worktree.ID: MergeVerdictBasis] = [:]
  /// What each verdict cost, which spreads a re-ask of every branch over
  /// several rounds; a test sets `budget` to see them spread.
  @ObservationIgnored var mergeReads = MergeReadLog()
  /// Each worktree's path with its symlinks resolved, for placing a report that
  /// names only a directory. Stale where a link is repointed or the path was away.
  @ObservationIgnored var resolvedWorktreeComponents: [Worktree.ID: [String]] = [:]
  /// Worktrees whose kept resolution was made while their directory was away.
  @ObservationIgnored var worktreesResolvedWhileMissing: Set<Worktree.ID> = []
  /// Those being looked at again, one at a time each, so a hung mount holds a
  /// thread per worktree on it and no other worktree waits on it.
  @ObservationIgnored var resolutionsBeingRechecked: Set<Worktree.ID> = []
  /// `git rev-parse --git-common-dir` per project, asked once. The watcher
  /// and the records check run from it without spawning git.
  @ObservationIgnored var commonGitDirectories: [Project.ID: URL] = [:]
  /// Written from the sidebar's body, so not observed: a write there would
  /// invalidate the body writing it.
  @ObservationIgnored var worktreeSortCache = WorktreeSortCache()
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
  /// Worktrees whose removal is reading their status.
  @ObservationIgnored var removalsAwaitingStatus: Set<Worktree.ID> = []
  /// Each removal's read until git answers, which outlives the removal's wait
  /// on a dead mount; a later removal waits on it rather than start another.
  @ObservationIgnored var removalStatusReads: [Worktree.ID: Task<Bool, Never>] = [:]
  /// How long a removal waits for that read before it asks anyway.
  @ObservationIgnored var removalStatusWait: Duration = .seconds(3)
  /// The removal asked last, the only one whose read may put up a dialog.
  @ObservationIgnored var latestRemovalRequestID: Worktree.ID?

  @ObservationIgnored var pendingSave: Task<Void, Never>?
  @ObservationIgnored var autosave: Task<Void, Never>?
  /// Set where another copy holds the socket: two copies autosaving one file
  /// leave the last writer's, so this one writes nothing; see state-and-store.md.
  @ObservationIgnored var isYieldingToRunningInstance = false
  /// Set while saves are failing, so the alert is raised once rather than
  /// again after every change until the disk is writable.
  @ObservationIgnored var hasReportedSaveFailure = false

  public var workspace: Workspace { store.workspace }

  /// Dependencies are passed in so tests run the whole model against fakes.
  /// The platform GUI passes its real ones.
  public init(
    store: WorkspaceStore,
    host: any TerminalSurfaceHost<Surface>,
    coordinator: WorktreeCoordinator?,
    watcher: any DirectoryWatcher,
    platform: any Platform = NullPlatform(),
    stateSource: any SessionStateSource = NullSessionStateSource(),
    notifier: any SessionNotifier = NullNotifier(),
    loadError: (any Error)? = nil
  ) {
    self.store = store
    self.host = host
    self.platform = platform
    self.reconciler = SessionReconciler(store: store, host: host)
    self.coordinator = coordinator
    self.watcher = watcher
    self.stateSource = stateSource
    self.notifier = notifier
    self.restoredSessionIDs = Set(store.workspace.sessions.map(\.id))

    reloadThemes()
    refreshNewTabAgents()
    host.apply(currentTheme, appearance: store.workspace.appearance)
    // Said on the process's PATH alone. `refreshLoginEnvironment` looks again
    // on the login shell's and takes this back if it finds git there.
    if let loadError {
      present(loadError)
    } else if coordinator == nil {
      present(GitUnavailable())
    }

    // Nothing is selected at launch, so no shell starts until the user picks
    // a worktree. Saved tabs stay saved and open with that first click.
    store.selectWorktree(nil)
    wireCallbacks()
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
  /// responder and reports the focus back through the reconciler.
  public func focusSurface(_ id: TerminalSession.ID) {
    host.focus(id)
  }

  /// Shells actually running, as opposed to saved tabs waiting to be opened.
  public var liveTerminalCount: Int { liveSessionIDs.count }

  func liveTerminalCount(in worktree: Worktree.ID) -> Int {
    workspace.sessions(in: worktree).filter { liveSessionIDs.contains($0.id) }.count
  }
}

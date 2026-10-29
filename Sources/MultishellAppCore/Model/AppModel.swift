import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

// Every stored property must be declared here, no extension holding one.
// swiftlint:disable file_length
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
  @ObservationIgnored let messageSource: any MessageSource
  @ObservationIgnored let notifier: any SessionNotifier
  @ObservationIgnored let watcher: any DirectoryWatcher
  @ObservationIgnored let themesDirectory: URL
  /// `var`: git is looked up again once the login shell's PATH is known, which
  /// is after this is built. See `refreshLoginEnvironment`.
  @ObservationIgnored var coordinator: WorktreeCoordinator?
  /// Sessions that came off disk this run. Their agent tabs resume rather
  /// than start afresh; see `preparedForLaunch`.
  @ObservationIgnored let restoredSessionIDs: Set<TerminalSession.ID>

  var presentedError: PresentedError? {
    didSet { noteAlertRaised(over: oldValue) }
  }
  @ObservationIgnored var alertsByRequest: [UUID: RequestAlerts] = [:]
  /// Only these file an alert: a task a request left running carries its id on.
  @ObservationIgnored var requestsBeingAnswered: Set<UUID> = []
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
  /// The quick switcher while it is up; see `toggleQuickSwitcher`.
  public internal(set) var quickSwitcher: QuickSwitcherState?
  /// The worktree row whose pull request and CI popover is open: here, not in
  /// the row, so a request can open it and `ui dismiss` close it.
  public internal(set) var servicesPopoverWorktreeID: Worktree.ID?
  /// Worktrees by when they were last selected, newest first, for the
  /// switcher's Recent. Unobserved, as the selection writing it redraws anyway.
  @ObservationIgnored var recentWorktreeIDs: [Worktree.ID] = []
  /// The project a menu asked the settings window for; `settingsWindowProjectID`
  /// is the one it shows.
  var requestedSettingsProjectID: Project.ID?
  /// The worktree showing its name field. Runtime state, so the menu that
  /// starts a rename and the row that draws it need not know each other.
  var renamingWorktreeID: Worktree.ID?
  /// The tab whose strip shows a name field; a commit arriving after the edit
  /// ended is ignored.
  public internal(set) var renamingTabID: TerminalTab.ID?
  /// The panes and file tabs with a find bar up, each its own; see `showFind`.
  /// Runtime state, dropped with the session or the tab.
  public internal(set) var findBarTargetIDs: Set<FindTargetID> = []
  /// Each target's find text, kept across closes so Cmd+F then Return repeats
  /// the last search there; read through `findText(of:)`.
  var findTexts: [FindTargetID: String] = [:]
  /// Targets whose bar has a Cmd+F to answer, claimed through `takeFindFieldRequest`;
  /// a bar a worktree switch brings back has none. See terminals.md.
  public internal(set) var findFieldRequests: Set<FindTargetID> = []
  /// Targets whose search has a selected match: a step has gone since the find
  /// text was set. See `step(_:in:)`.
  var steppedFindTargetIDs: Set<FindTargetID> = []
  /// The target whose bar's field has the keyboard, which the menu's find items
  /// act on ahead of the focused one, a field taking no store focus.
  var findFieldTargetID: FindTargetID?
  /// The selection each target's Cmd+F last took as its find text; see `showFind`.
  var takenFindSelections: [FindTargetID: String] = [:]
  /// What the engine's search last counted in each pane with a bar up.
  var searchCounts: [TerminalSession.ID: PaneSearchCount] = [:]
  /// What each file tab's search found, here and not by the engine.
  var fileFindResults: [FileTab.ID: FileFindResult] = [:]
  /// Each file tab's selected text, which a Cmd+F there finds.
  @ObservationIgnored var fileTabSelections: [FileTab.ID: String] = [:]
  /// Written on every scroll, which nothing redraws for.
  @ObservationIgnored var fileTabScrolls: [FileTab.ID: FileTabScroll] = [:]
  @ObservationIgnored var fileFindsShown: [FileTab.ID: FileFindShown] = [:]

  /// Whether the Files panel is open: one switch for the window, which the
  /// view keeps per machine as it keeps the sidebar's width.
  public internal(set) var showsFilesPanel = false
  /// What the panel shows of each worktree. Runtime state.
  var filesPanelStates: [Worktree.ID: FilesPanelState] = [:]
  /// What each worktree's index tracks, read while its panel is shown.
  var trackedFiles: [Worktree.ID: TrackedFiles] = [:]
  /// What git ignores in each worktree, a whole folder as one entry, read
  /// while its panel is shown.
  var ignoredEntries: [Worktree.ID: [String]] = [:]
  /// Each worktree's read ignored folders, open or shut, listed from disk.
  var ignoredFolderEntries: [Worktree.ID: [String: [IgnoredFolderEntry]]] = [:]
  /// One read of what git ignores per worktree, paced after it.
  @ObservationIgnored var ignoredEntriesReads = CoalescedReads<Worktree.ID>()
  /// Each worktree's opened submodules, read as repositories of their own.
  var submoduleReadings: [Worktree.ID: [String: SubmoduleReading]] = [:]
  @ObservationIgnored var panelFolderReads = CoalescedReads<PanelFolderRead>()
  /// The tree each panel last drew, rebuilt only when what it was built from changed.
  @ObservationIgnored var fileTreeCache: [Worktree.ID: FileTreeCacheEntry] = [:]
  /// Listings too large to build in a render, held until a render takes one.
  @ObservationIgnored var fileTreeListings: [Worktree.ID: FileTreeListing] = [:]
  @ObservationIgnored var pendingFileTreeListings: [Worktree.ID: Task<Void, Never>] = [:]
  /// Changed paths too many to build in a render, held as a listing is.
  @ObservationIgnored var fileTreeChanges: [Worktree.ID: FileTreeChanges] = [:]
  @ObservationIgnored var pendingFileTreeChanges: [Worktree.ID: Task<Void, Never>] = [:]
  /// Read by every panel render, so a landing redraws; the builds are unobserved.
  var fileTreeBuildLandings = 0
  /// One coalesced listing read per worktree; see `scheduleTrackedFilesRead`.
  @ObservationIgnored var pendingTrackedFilesReads: [Worktree.ID: Task<Void, Never>] = [:]
  /// What each worktree changed since its base branch, read while its panel
  /// shows Branch.
  var branchChanges: [Worktree.ID: BranchChanges] = [:]
  /// The base each worktree's last Branch read failed against, which the footer says.
  var failedBranchReads: [Worktree.ID: String] = [:]
  @ObservationIgnored var branchChangesReads = CoalescedReads<Worktree.ID>()

  /// Each file tab's last read. Runtime only: contents never reach the file,
  /// so after a relaunch a deleted file's tab shows its committed text removed.
  public internal(set) var fileTabReadings: [FileTab.ID: FileTabReading] = [:]
  /// The file tab a reconcile handed the keyboard to, taken by its view
  /// through `takeFileTabFocusRequest`, as a find field takes its request.
  var fileTabFocusRequest: FileTab.ID?
  /// Taken by each file tab's view, which alone knows the selection a step counts from.
  var changeStepRequests: [FileTab.ID: [CycleDirection]] = [:]
  var fileTabChangeSteps: [FileTab.ID: ChangeSteps] = [:]
  @ObservationIgnored var fileTabSteppedChangeAnchors: [FileTab.ID: ChangeAnchor] = [:]
  @ObservationIgnored var fileTabReadLog = FileTabReadLog()
  /// One coalesced read per file tab; see `scheduleFileTabRead`.
  @ObservationIgnored var pendingFileTabReads: [FileTab.ID: Task<Void, Never>] = [:]

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
  public internal(set) var areDebugToolsEnabled = false
  /// A sample a second while debug tools are on; see `takeDebugSample`.
  var debugHistory = DebugHistory()
  /// Which processes each pane runs, as of the last sample.
  var debugProcessAttribution = PaneProcessAttribution.empty
  /// What each pane's terminal held at the last sample, scrollback included.
  var debugTerminalMemoryBySession: [TerminalSession.ID: UInt64] = [:]
  /// What the panel shows while paused, the sampling going on under it.
  var pausedDebugSnapshot: DebugSnapshot?
  @ObservationIgnored var debugSampler = DebugSampler()
  /// The newest git runs one by one, for `multishell debug git`; no view reads it.
  @ObservationIgnored var debugGitRuns = DebugGitRunLog()

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
  /// The sheet's first tab for each worktree it created, kept until that tab
  /// opens or would have: after any setup, or a failed one's Dismiss.
  @ObservationIgnored var newWorktreeFirstTabs: [Worktree.ID: NewWorktreeFirstTab] = [:]
  /// The task each agent tab starts on, taken by its first launch.
  @ObservationIgnored var pendingAgentTasks: [TerminalSession.ID: String] = [:]

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
  /// Where each reporting agent says it runs, for its file mentions. Not
  /// observed, as nothing drawn reads it and a hook's cwd moves often.
  @ObservationIgnored var reportedAgentDirectories: [TerminalSession.ID: URL] = [:]
  /// The agent a shell said it was starting, kept only while that command
  /// runs. What marks a pane where nobody installed the agent's hooks.
  var commandAgentIDs: [TerminalSession.ID: String] = [:]
  /// Keys whose banner may still be on screen, so one is taken back only
  /// where there is one to take back. A key leaves as its banner does.
  @ObservationIgnored var notifiedKeys: Set<SessionStates.Key> = []
  @ObservationIgnored var notificationLog = NotificationLog()
  /// Worktrees whose saved tabs have been given live shells. Empty at launch,
  /// so a relaunch starts nothing; shrinks only as worktrees are forgotten.
  @ObservationIgnored var warmWorktrees: Set<Worktree.ID> = []
  /// Each project's exports of its repository's file, landing in the order
  /// they were asked.
  @ObservationIgnored var sharedSettingsExportOrders: [Project.ID: SaveOrder] = [:]
  /// Settable so a test stands in a mount that never answers.
  @ObservationIgnored var directoryProbe = DirectoryProbe()
  @ObservationIgnored var pidWatch: Task<Void, Never>?
  @ObservationIgnored var failedWorkerSweep: Task<Void, Never>?
  @ObservationIgnored var failedWorkerSweepDue: Date?
  /// How long a failed worker stays listed. Settable so a test does not wait
  /// the full linger.
  @ObservationIgnored var failedWorkerLingering = SessionStates.failedWorkerLingering
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
    { try AppLaunchFiles.refresh(helper: $0) }
  @ObservationIgnored var sweepDropCopies: @Sendable () -> Void = {
    DropCopies.sweep()
  }

  @ObservationIgnored let oneShotRunner = OneShotRunner()
  /// The environment of the user's interactive login shell, once captured.
  /// `nil` until the shell has answered and its PATH has been scanned.
  var loginEnvironment: LoginShellEnvironment?
  /// Which catalogue agents that environment's PATH has.
  public internal(set) var agentDetection = AgentDetection.empty {
    didSet { rebuildNewTabAgents() }
  }
  /// The agents a New Tab menu lists, held rather than worked out: a strip's
  /// body reads it on every render. Rebuilt by `rebuildNewTabAgents`.
  public internal(set) var newTabAgentIDs: [String] = []
  /// Which shells the machine has, from `/etc/shells` and that PATH.
  public internal(set) var shellDetection = ShellDetection.empty
  /// Which catalogue editors are installed, by application id or shim.
  public internal(set) var editorDetection = EditorDetection.empty
  /// Which agents' hooks are in place, by catalogue id. Read from disk by
  /// `refreshInstallState`; nothing watches the files.
  var installedAgentHooks: Set<String> = []
  /// Installed, but not what this build writes.
  var staleAgentHooks: Set<String> = []
  public internal(set) var isCommandLineToolInstalled = false
  /// What the notification centre has been told about this app. The system's
  /// answer, not the workspace's, and changeable while the app runs.
  var notificationAuthorization = NotificationAuthorization.notAsked
  var themeCatalogue = ThemeCatalogue.builtinsOnly
  @ObservationIgnored var alertedMissingAgentIDs: Set<String> = []

  public internal(set) var autoRenames: [Worktree.ID: AutoRenameState] = [:]
  var scannedBranchTips: [Worktree.ID: String] = [:]
  /// `git status` per worktree. Runtime only; see `WorktreeStatus`.
  public internal(set) var statuses: [Worktree.ID: WorktreeStatus] = [:]
  /// Whether each worktree's branch has already landed on its project's
  /// default branch. Runtime only; see `WorktreeMergeState`.
  var mergeStates: [Worktree.ID: WorktreeMergeState] = [:]
  /// What each project's merges are measured against, `origin/main` and the
  /// like, once a scan answers.
  var defaultBranchScans: [Project.ID: DefaultBranchScan] = [:]
  /// When each worktree's branch was last committed to. Runtime only: the
  /// workspace must not be rewritten because someone committed.
  var lastCommitDates: [Worktree.ID: Date] = [:]
  @ObservationIgnored let remoteState = RemoteState()
  /// Projects whose directory has gone. Kept in the sidebar, dimmed, rather
  /// than dropped: an unmounted drive should not delete someone's setup.
  public internal(set) var missingProjects: Set<Project.ID> = []
  /// What each worktree's merge verdict was computed from, so a refresh
  /// that finds nothing moved spawns no git; see `MergeVerdictBasis`.
  @ObservationIgnored var mergeVerdictBases: [Worktree.ID: MergeVerdictBasis] = [:]
  /// What each verdict cost, which spreads a re-ask of every branch over
  /// several rounds; a test sets `budget` to see them spread.
  @ObservationIgnored var mergeReadLog = MergeReadLog()
  @ObservationIgnored var pathResolutions = WorktreePathResolutions()
  /// `git rev-parse --git-common-dir` per project, asked once. The watcher
  /// and the records check run from it without spawning git.
  @ObservationIgnored var commonGitDirectories: [Project.ID: URL] = [:]
  /// What the watcher was last asked to watch, so a list that changed none
  /// of it starts no new stream; nil where no list may count as unchanged.
  @ObservationIgnored var armedDirectories: [URL]?
  /// Counts re-arms begun, so one overtaken while it awaited arms nothing.
  @ObservationIgnored var watcherRearms = 0
  /// Read on the short poll, file events missing what another machine writes.
  @ObservationIgnored var worktreesOnNetworkVolumes: Set<Worktree.ID> = []
  /// A seam: no test machine has a share to put a worktree on.
  @ObservationIgnored var isOnLocalVolume: @Sendable (URL) -> Bool = \.isOnLocalVolume
  /// A seam, as `isOnLocalVolume` is: a test holds one read back to overtake it.
  @ObservationIgnored var loadThemeCatalogue = ThemeCatalogue.loadRemovingStrayExamples(from:)
  @ObservationIgnored var themeReloads = 0
  /// Written from the sidebar's body, so not observed: a write there would
  /// invalidate the body writing it.
  @ObservationIgnored var worktreeSortCache = WorktreeSortCache()
  /// What the last refresh of each project was computed from; see
  /// `refreshProjectsIfChanged`.
  @ObservationIgnored var worktreeRecords: [Project.ID: WorktreeRecords] = [:]
  @ObservationIgnored var statusPolling: Task<Void, Never>?
  /// When each worktree's status was last read and how often it is read; a
  /// test reading right after a change sets `pace` to `.unpaced`.
  @ObservationIgnored var statusReadLog = StatusReadLog()
  /// One coalesced status refresh per worktree; see `scheduleStatusRefresh`.
  @ObservationIgnored var pendingStatusRefreshes: [Worktree.ID: Task<Void, Never>] = [:]
  /// One coalesced branch scan per project; see `scheduleBranchScan`.
  @ObservationIgnored var pendingBranchScans: [Project.ID: Task<Void, Never>] = [:]
  /// What git ignores in each worktree, as far as file changes have asked it.
  @ObservationIgnored var ignoreVerdicts: [Worktree.ID: IgnoreVerdicts] = [:]
  /// The read after the filter text changes, one per pause in typing, and
  /// the rows the poll kept reading through every keystroke of that burst.
  @ObservationIgnored var pendingRevealedRowsRead:
    (polledThroughout: Set<Worktree.ID>, task: Task<Void, Never>)?
  @ObservationIgnored var removalRequests = WorktreeRemovalRequests()

  @ObservationIgnored var pendingSave: Task<Void, Never>?
  /// How long a change waits for the next before it is saved; tests set it to zero.
  @ObservationIgnored var saveDebounce: Duration = .milliseconds(300)
  @ObservationIgnored var autosave: Task<Void, Never>?
  /// Set where another copy holds the socket: two copies autosaving one file
  /// leave the last writer's, so this one writes nothing; see state-and-store.md.
  @ObservationIgnored var isYieldingToRunningInstance = false
  /// Set by `multishell quit` while it quits, having already refused over a
  /// working agent, so the quit confirmation is not raised.
  @ObservationIgnored var quitsWithoutAsking = false
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
    themesDirectory: URL,
    platform: any Platform = NullPlatform(),
    messageSource: any MessageSource = NullMessageSource(),
    notifier: any SessionNotifier = NullNotifier(),
    loadError: (any Error)? = nil,
  ) {
    self.store = store
    self.host = host
    self.platform = platform
    self.reconciler = SessionReconciler(store: store, host: host)
    self.coordinator = coordinator
    self.watcher = watcher
    self.themesDirectory = themesDirectory
    self.messageSource = messageSource
    self.notifier = notifier
    self.restoredSessionIDs = Set(store.workspace.sessions.map(\.id))

    take(loadThemeCatalogue(themesDirectory))
    rebuildNewTabAgents()
    host.apply(currentTheme, appearance: store.workspace.appearance)
    // A git missing here is said once the login shell's PATH lacks it too.
    if let loadError { present(loadError) }

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
    pidWatch?.cancel()
  }
}

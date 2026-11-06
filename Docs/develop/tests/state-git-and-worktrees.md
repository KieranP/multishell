# State, git and worktrees

Which test catches which breach of the rules for saved state, processes, git,
worktrees, status reads, services and debug sampling. Why each rule holds is in
`design/`.

## What catches a breach of the rules

- **Persisted defaults, unknown enum values included**: each persisted type's
  own suite, WorkspaceTests and ProjectSettingsTests+Decoding the largest.
- **An old state file still loads with what it said**:
  WorkspaceStoreTests+TabGroupMigration reads a real file from before groups,
  WorkspaceStoreTests+NotificationMigration the picker this build replaced with
  toggles.
- **The workspace invariants and the reference repair**:
  WorkspaceStoreTests+Invariants and AppModelTests, random operations, printing
  the failing seed and step.
- **No blocking in the core**: ProcessRunnerTests runs at least four children
  per core, and 96, and counts what each saw running beside it. Starved, at most
  a thread per core is inside a run; unstarved, nearly all are, the hold being
  long against a launch. A wall-clock bound was the runner's mood, and no figure
  both had headroom on one core and caught twelve starving.
- **Blocking work sent off the main actor leaves the cooperative pool**:
  RunOnDispatchTests holds one more `runOnDispatch` call than there are cores
  and still releases them all from a task.
- **Descriptor exhaustion** lowers the process-wide limit, so
  DescriptorExhaustionTests runs only with `MULTISHELL_EXHAUST_DESCRIPTORS` set
  and a filter.
- **The app's own git reads write nothing under `.git`**:
  WorktreeGitTests+ReadsWriteNothing, AppModel+FileChangesTests+RealWatcher
  under a real watcher, and WorktreeGitStatusTests for the index lock.
- **A tree still being built wears no badge, and a stage on a listed worktree
  keeps the one it earned**: AppModel+StatusReadsTests+WhileBeingWritten and the
  merged-badge test in AppModelBranchScansTests.
- **State that will not open, not just will not decode, is moved aside**, and
  one that cannot be moved is never saved over: StateFileTests and
  WorkspaceStoreTests+Restoring.
- **The user's git config cannot change what a read means**: GitRunnerTests
  reads the isolated keys back and watches an all-untracked worktree read dirty.
- **A tag sharing a branch's or the base's name decides nothing**:
  WorktreeCoordinatorMergesTests, its fixture merging by refname or git takes
  the tag. WorktreeGitBranchesTests holds the New Worktree sheet's names bare
  under the same tie.
- **A poll reconciles without taking the keyboard, and a cross-group drop takes
  it with the tab**: AppModelWorktreeListRefreshTests and AppModelTabMovesTests.
- **A tab id written twice keeps the copy whose worktree is still there**:
  WorkspaceRepairTests, the dead one listed first.
- **A worktree path holding a newline is one worktree**:
  WorktreeGit+ListingTests against real git.
- **A hook variable renamed under hooks already written**: HookVariableTests.
- **Export keeps a hook the user refused** without trusting it, and keeps the
  directory and path lists an unanswered file holds; **the trust answer travels
  to the new digest**: AppModelSharedSettingsExportTests.
- **A symlink planted after the file was read is caught**:
  AppModelSharedSettingsTests watches the create refuse the directory rather
  than check out through it.
- **What the app cannot read is written back as it was**:
  SharedProjectSettingsTests over an unknown key, a nested one, an order no
  build names and a wrong-typed flag.
- **A stage ending while the board is up leaves it up**, and the first tab opens
  under the create settings, and out of view without moving the selection or the
  keyboard: AppModelWorktreeSetupTests.
- **A status answering after its worktree went badges nothing**:
  AppModelWorktreeStatusRefreshTests.
- **A focus report that changes nothing writes nothing**: WorkspaceStoreTests,
  through observation tracking, a re-read of a repository's file held to the
  same rule. Its counter counts store operations rather than writes.
- **Only a repository's file lists are held to the checkout**:
  WorktreeFilesTests gets a user's home and absolute entries back as skipped,
  with no failure raised.
- **Neither end is a licence to write outside the worktree**: the same suite
  points a user's entry at a parent path, the worktree nested so the mirrored
  destination is genuinely elsewhere, and finds nothing written.
- **git's own children are looked up on the login PATH**: GitRunnerTests,
  through an alias that runs a helper on a PATH of the test's own; the same
  runner without it fails, which is what makes the pass mean something.
- **A runner given only a search path runs the git on it**, and one named
  outright wins: GitRunnerTests. The default once ignored the path and ran the
  process's own.
- **A branch name git will reject is refused before the pre-create hook**:
  AppModelWorktreeCreationTests, the rules themselves held against real git in
  GitBranchNameTests, the existing-branch path in
  WorktreeCoordinatorCreationTests.
- **A bare rebase that replayed nothing is not a landing**:
  WorktreeCoordinatorMergesTests, and ReflogWorkParserTests for the finish
  wording old and new.
- **A worktree resolved while its directory was missing resolves again once the
  directory is seen**: AppModelWorktreeLookupTests.
- **Removing the main worktree is refused before the hook and the Trash**:
  AppModelWorktreeRemovalTests. Without the guard that test bins the fixture.
- **Removing one worktree leaves the record of another whose directory is
  away**: WorktreeGitRemovalTests. A Trash that refuses leaves a lock and its
  reason in place, and **a Trash that takes nothing stops the removal there**,
  the record's removal being what would unlink a directory still in place:
  WorktreeCoordinatorRemovalTests.
- **A refused create leaves no container directory**:
  WorktreeCoordinatorCreationTests.
- **A branch lookup that failed is not a new branch**, so a stopped create
  deletes nothing: WorktreeCoordinatorStoppedAddTests.
- **A read-only directory copies whole and keeps its modes**:
  WorktreeFilesTests.
- **A checkout git refuses to read is still removed with its hooks, and a locked
  stale record is forgotten**: WorktreeGitRemovalTests.
- **Launch opens terminals without waiting on the dropped-file sweep**:
  AppModelLifecycleTests.
- **A row the filter shows is polled, and one on screen is read before its
  removal dialog**: AppModel+StatusReadsTests+VisibleRows and
  AppModel+WorktreeRemovalRequestTests+StatusReads, the latter also holding that
  a late removal read leaves the dialog up and a repeated click reads once. **A
  pause in typing reads only the rows the filter brought back**:
  AppModelRevealedRowsTests.
- **A removal whose status read hangs or fails still asks, saying the changes
  went unread**, and a second ask while the read hangs starts no other:
  AppModel+WorktreeRemovalRequestTests+StatusReads.
- **A row the poll is reading is not read again, but a change seen meanwhile is
  read again once it lands**: AppModelStatusReadsTests and
  AppModelWorktreeStatusRefreshTests.
- **A confirmed removal trashes or deletes as its dialog said**, though the
  setting changed while it was up: AppModelWorktreeRemovalRequestTests.
- **The Trash is asked off the main thread**:
  AppModel+WorktreeRemovalTests+Trash.
- **A hook still running when its worktree is removed in a terminal is ended**,
  bounded and with no alert:
  AppModel+WorktreeListRefreshTests+RemovedOutsideTheApp.
- **The ownership rules those rest on**: WorktreeStageHandlesTests, a stop
  handle dropped only by the stage that installed it and only the newest create
  answering the sheet's Cancel, and WorktreePathClaimsTests.
- **A failing refresh landing after its project was removed dims nothing**:
  AppModelWorktreeListRefreshTests.
- **A record git will neither remove nor prune after the Trash took the
  directory is its own failure**: WorktreeGitRemovalTests,
  PresentedRemovalFailureTests for the mapping. **A prune that leaves the record
  listed is still a failure**, and an unreadable or empty list counts as listed:
  the same suite.
- **A zero or non-finite split weight is refused on decode and on write**:
  PaneNodeDecodingTests and WorkspaceStoreTests.
- **A removal dialog left up for a worktree git no longer lists, and Remove
  offered on the main worktree**:
  AppModel+WorktreeListRefreshTests+RemovedOutsideTheApp and
  AppModelWorktreeRemovalRequestTests, both through the one place each is
  decided.
- **A second copy of the app writing the workspace file**:
  AppModelLifecycleTests. Given an in-use socket, it asks the platform to hand
  over, starts no poll and writes no file.
- **Two saves landing out of order**: WorkspaceStoreTests+OrderedSaves.
- **A stalled write holding the main actor**: SaveOrderTests.
- **A held write that needs a free pool thread**: HeldWriteTests blocks every
  one first.
- **Two exports landing out of order, and a poll between an export's write and
  its finish**: AppModel+SharedSettingsExportTests+Overlaps.
- **What the git badge counts**: NumstatParserTests, NulPathListParserTests and
  UntrackedLineCounterTests, including a symlink that is never followed, a file
  that would cross the budget and the files past the cap. **The three together
  on real git**: WorktreeGitStatusTests, once per indicator setting, each file
  in an untracked directory counted with its lines and a merge conflict no file
  with no lines. Its +Changes extension holds the per-file list the badge, its
  tooltip, the removal dialog and the Files panel share.
- **A repository whose own config says not to look at untracked files**:
  GitRunnerTests, where the lines are counted anyway.
- **Changing the indicator reads every badge at once**:
  AppModelStatusReadsTests. A read started before the change badges nothing:
  AppModelWorktreeStatusRefreshTests.
- **The status poll asking a missing project or a slow checkout**:
  AppModelStatusReadsTests, and AppModelWorktreeStatusRefreshTests for a single
  row's read of that slow worktree and for a read discarded mid-flight, which
  must leave the next read due.
- **The pacing rule itself**: StatusReadPaceTests, and StatusReadLogTests for
  the readings it is applied to. The harness runs unpaced, or a read right after
  a change would be skipped; a test of what the pace holds back sets its own.
- **A watcher tick re-reading every project**: AppModelWorktreeListRefreshTests.
- **A worktree on a volume that does not answer is refused without waiting on
  it, and asked once**: AppModelWorktreeSelectionTests.
- **The xcrun shim is looked past, and xcrun never asked with no developer
  directory**: GitExecutableTests.
- **Pull requests and CI runs**: the tools' output in MultishellServicesTests,
  `gh`'s from this repository and CircleCI 1.11's from a work project, scrubbed,
  through fake executables on no account; matching in
  WorktreeServices+MatchingTests; the model's reads, pacing and Create Pull
  Request in the suites under `Model/Services/` against fake hosts, never the
  developer's `gh` or `circleci`.
- **The merge reads' round budget and their one shared width**:
  MergeReadLogTests, AppModelBranchScansTests for a lone project's refresh, and
  WorktreeCoordinator+MergesTests+ReadWidth across two projects.
- **A child with a terminal to stop it, or ended by its task's cancel**:
  ProcessRunnerTests.
- **A spawn that forks the app to get that session**: ProcessRunnerTests counts
  the atfork handler's calls, which `posix_spawn` never makes. Anything else in
  the test process that forks would fail it.
- **A timeout whose child exits 0 is withdrawn and frees its stopper**:
  ProcessStopperTests stages the race rather than timing it, with a perl child
  that blocks SIGHUP.
- **A state file with file tabs read by the build before them keeps this build's
  terminal order, and one that build wrote takes its order from `tabs`**:
  WorkspaceStoreTests+FileTabs and Workspace+RepairTests+FileTabs.
- **The trust question names its fields in the catalogue's words**:
  SharedProjectSettings+TrustTests.
- **A sample begun before the debug tools go off lands nowhere**, nor once they
  are back on: AppModelDebugToolsTests.
- **A display asleep is no frames, not a stall**, while a reading held late by a
  stall keeps its gap: FrameRateMeterTests.
- **CPU time is mach ticks, not nanoseconds**: KernelResourceUsageTests holds
  this process's against its own CPU clock within a factor of two, the misread
  being about 42 times short.
- **A git run that starts and ends between two samples still counts**:
  AppModelDebugSamplingTests, and ProcessRunnerTests+ExitUsage reading the
  child's usage as it exits.

# State, git and worktrees

Which test catches which breach of the rules for saved state, processes, git,
worktrees, status reads, services and debug sampling. Why each rule holds is in
`design/`.

## What catches a breach of the rules

- **Persisted defaults, unknown enum values included**: each persisted type's
  own suite, WorkspaceTests and ProjectSettingsTests+Decoding the largest.
- **An old state file still loads with what it said**: WorkspaceStoreTests
  +TabGroupMigration and +NotificationMigration, each from a real file, and
  WorkspaceStoreTests+FileTabs with Workspace+RepairTests+FileTabs for the build
  before file tabs.
- **The workspace invariants and the reference repair**:
  WorkspaceStoreTests+Invariants and AppModelTests, by random operations.
- **No blocking in the core**: ProcessRunnerTests counts what each child saw
  running beside it: starved, at most a thread per core is inside a run;
  unstarved, nearly all are. A wall-clock bound was the runner's mood, and no
  figure both had headroom on one core and caught twelve starving.
- **Blocking work sent off the main actor leaves the cooperative pool**:
  RunOnDispatchTests.
- **Descriptor exhaustion** lowers the process-wide limit, so
  DescriptorExhaustionTests runs only with `MULTISHELL_EXHAUST_DESCRIPTORS` set
  and a filter.
- **The app's own git reads write nothing under `.git`**:
  WorktreeGitTests+ReadsWriteNothing, AppModel+FileChangesTests+RealWatcher and
  WorktreeGitStatusTests.
- **A tree still being built wears no badge**:
  AppModel+StatusReadsTests+WhileBeingWritten and AppModelBranchScansTests.
- **State that will not open is moved aside, and never saved over**:
  StateFileTests and WorkspaceStoreTests+Restoring, with a link saved through in
  StateFileTests and seeded over in ThemeCatalogueTests.
- **The user's git config cannot change what a read means**: GitRunnerTests, and
  WorktreeCoordinatorMergesTests under `column.ui`.
- **A tag sharing a branch's or the base's name decides nothing**:
  WorktreeCoordinatorMergesTests, its fixture merging by refname or git takes
  the tag, and WorktreeGitBranchesTests.
- **A poll reconciles without taking the keyboard, and a cross-group drop takes
  it with the tab**: AppModelWorktreeListRefreshTests and AppModelTabMovesTests.
- **A tab id written twice keeps the copy whose worktree is still there**:
  WorkspaceRepairTests.
- **A worktree path holding a newline is one worktree**:
  WorktreeGit+ListingTests.
- **A hook variable renamed under hooks already written**: HookVariableTests.
- **Export keeps a refused hook untrusted, and the trust answer travels to the
  new digest**: AppModelSharedSettingsExportTests. **A symlink planted after the
  read is caught**: AppModelSharedSettingsTests. **What the app cannot read is
  written back as it was**: SharedProjectSettingsTests. **The trust question
  names its fields in the catalogue's words**: SharedProjectSettings+TrustTests.
- **A stage ending while the board is up**: AppModelWorktreeSetupTests.
- **A focus report that changes nothing writes nothing**: WorkspaceStoreTests.
  Its counter counts store operations rather than writes.
- **A repository's file lists stay inside the worktree**: WorktreeFilesTests,
  the worktree nested so the mirrored destination of a parent path is genuinely
  elsewhere.
- **git's own children are looked up on the login PATH**: GitRunnerTests,
  through an alias that runs a helper on a PATH of the test's own; the same
  runner without it fails, which is what makes the pass mean something.
- **A runner given only a search path runs the git on it**: GitRunnerTests. The
  default once ignored the path and ran the process's own.
- **A branch name git will reject is refused before the pre-create hook**:
  AppModelWorktreeCreationTests, GitBranchNameTests against real git, and
  WorktreeCoordinatorCreationTests.
- **A bare rebase that replayed nothing is not a landing**:
  WorktreeCoordinatorMergesTests, and ReflogWorkParserTests for git's finish
  wording old and new.
- **A worktree resolved while its directory was missing**:
  AppModelWorktreeLookupTests.
- **Removing the main worktree is refused before the hook and the Trash**:
  AppModelWorktreeRemovalTests. Without the guard that test bins the fixture.
- **A removal touching another worktree's record, a checkout git refuses to
  read, or a record git will neither remove nor prune**:
  WorktreeGitRemovalTests, with PresentedRemovalFailureTests for the wording.
- **A Trash that takes nothing stops the removal there**, the record's removal
  being what would unlink a directory still in place:
  WorktreeCoordinatorRemovalTests. **The Trash is asked off the main thread**:
  AppModel+WorktreeRemovalTests+Trash.
- **A confirmed removal does what its dialog said, and Remove is not offered on
  the main worktree**: AppModelWorktreeRemovalRequestTests. **A worktree removed
  in a terminal ends its hook and its dialog**:
  AppModel+WorktreeListRefreshTests+RemovedOutsideTheApp.
- **A refused or stopped create leaves nothing and deletes nothing**:
  WorktreeCoordinatorCreationTests and WorktreeCoordinatorStoppedAddTests. **A
  read-only directory copies whole**: WorktreeFilesTests. **The ownership rules
  creation and removal rest on**: WorktreeStageHandlesTests and
  WorktreePathClaimsTests.
- **Launch waiting on the dropped-file sweep**: AppModelLifecycleTests, whose
  sweep can finish only after `start` has returned.
- **Which rows are read, and when**: AppModel+StatusReadsTests+VisibleRows and
  AppModelRevealedRowsTests for what the filter shows,
  AppModel+WorktreeRemovalRequestTests+StatusReads for a removal's read that
  hangs or fails, AppModelStatusReadsTests and
  AppModelWorktreeStatusRefreshTests for a read in flight, a late answer, a
  missing project and a slow checkout.
- **A failing refresh landing after its project was removed dims nothing**:
  AppModelWorktreeListRefreshTests.
- **A zero or non-finite split weight is refused**: PaneNodeDecodingTests and
  WorkspaceStoreTests. No test decodes a non-finite one.
- **A second copy of the app writing the workspace file**:
  AppModelLifecycleTests.
- **Two saves or exports landing out of order, and a stalled write holding the
  main actor**: WorkspaceStoreTests+OrderedSaves,
  AppModel+SharedSettingsExportTests+Overlaps and SaveOrderTests. **A held write
  that needs a free pool thread**: HeldWriteTests blocks every one first.
- **What the git badge counts**: NumstatParserTests, NulPathListParserTests and
  UntrackedLineCounterTests, and the three together on real git in
  WorktreeGitStatusTests. **A repository's own config hiding untracked files**:
  GitRunnerTests.
- **Changing the indicator reads every badge at once**: AppModelStatusReadsTests
  and AppModelWorktreeStatusRefreshTests.
- **The pacing rule itself**: StatusReadPaceTests and StatusReadLogTests. The
  harness runs unpaced, or a read right after a change would be skipped; a test
  of what the pace holds back sets its own.
- **A watcher tick re-reading every project**: AppModelWorktreeListRefreshTests.
- **A worktree on a volume that does not answer**:
  AppModelWorktreeSelectionTests.
- **The xcrun shim is looked past**: GitExecutableTests.
- **Pull requests and CI runs**: the tools' output in MultishellServicesTests,
  `gh`'s from this repository and CircleCI 1.11's and 1.13's from a work
  project, scrubbed; matching in WorktreeServices+MatchingTests; the model's
  side in the suites under `Model/Services/` against fake hosts, never the
  developer's `gh` or `circleci`.
- **The merge reads' round budget and their one shared width**:
  MergeReadLogTests, AppModelBranchScansTests and
  WorktreeCoordinator+MergesTests+ReadWidth.
- **A child with a terminal to stop it, or ended by its task's cancel**:
  ProcessRunnerTests.
- **A spawn that forks the app to get that session**: ProcessRunnerTests counts
  the atfork handler's calls, which `posix_spawn` never makes. Anything else in
  the test process that forks would fail it.
- **A timeout whose child exits 0 is withdrawn and frees its stopper**:
  ProcessStopperTests stages the race rather than timing it, with a perl child
  that blocks SIGHUP.
- **A sample landing after the debug tools go off**: AppModelDebugToolsTests.
  **A display asleep read as a stall**: FrameRateMeterTests. **A git run that
  starts and ends between two samples**: AppModelDebugSamplingTests and
  ProcessRunnerTests+ExitUsage.
- **CPU time is mach ticks, not nanoseconds**: KernelResourceUsageTests, within
  a factor of two of this process's CPU clock, the misread being about 42 times
  short.

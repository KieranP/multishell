# Tests

Which test catches which breach, and the conventions a new one follows. Why each
rule holds is in `Docs/design/`.

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
- **A shortcut's two spellings agree**: AppShortcutCatalogueTests. **The
  clipboard ones stay with the terminal**: GhosttyUnbindsTests, pinned against
  the config the engine was given.
- **Identifiers spelled in both Swift and the generated Info.plist still
  match**: InfoPlistTemplateTests. Nothing at build or run time notices these
  having parted.
- **The quit alert answers both keys under any language**: QuitAlertTests, with
  translated titles, since AppKit binds Escape by matching the English one.
- **A removal button keeps its red bezel and its Return**:
  DestructiveAlertTests. AppKit takes the key off at every layout and draws a
  default button in the accent colour. What a presented sheet draws is not
  testable here, so the suite holds the properties, bar macOS 27's alert button,
  which keeps no bezel colour: there the offscreen drawing is read.
- **Each override binds to its own setting**: AppModelSettingsBindingsTests, the
  override accessors all taking the same arguments and returning the same type.
- **Sidebar counts agree with the columns they summarise**:
  AppModelAgentBoardTests over every state and both filter positions, the counts
  being made without building a card. A pane whose reported agent has exited is
  a shell to the counts, the cards, the strip and its sidebar row alike, the
  four having once asked apart.
- **An agent mark that draws nothing**: AgentMarkShapeTests holds each mark to
  its square; a file that will not parse is left out of the table rather than
  crashing a view.
- **An agent typed at a prompt that marks nothing**: the placeholder test in
  ShellIntegrationScriptsTests holds the generated files to naming the agents,
  and ShellIntegrationScriptsTests+SessionReports runs the real shells. That
  caught a zsh word subscript taking characters for a command run by its path,
  which a syntax check cannot see.
- **A settings page outgrowing its fixed window**: ViewSettingsWindowTests lays
  each page out in a window never ordered in and holds it to the window's
  height, the content given the whole window with no tab band.
- **The bound is absolute, not a margin**: Project General sits 18.5 pt under
  it, so a macOS that grows a grouped form's rows fails this first, rightly.
  Project Agents measured 541 here and 539 on the CI runner. Appearance stays
  in: its font list is the machine's, but a picker is one row however long.
- **A page in parts is held part by part**: Project Hooks' three parts and
  Agents' Agent part. Hooks' Create part under a repository file asking for
  trust is its tallest, 593 pt of the 600.
- **One part is exempt**: Agents' Hooks part reads the machine on appear, so its
  height is the developer's. Width is not checkable at all, a minimum-size
  measurement reporting where text wraps.
- **A tab strip that stops answering the wheel**: SidewaysWheelViewTests sends a
  synthesized vertical scroll to the overlay over a real scroller, spinning the
  run loop by hand, since `run(until:)` returns at once while it has no source.
  The same event handed straight to the scroller moves it by nothing, which is
  why the catcher exists. ViewSidewaysWheelTests holds the marked scroller to
  being the strip's and the catcher to sitting outside it.
- **A word on screen with no translation, or a translation nothing shows**:
  TranslationTests, one per catalogue (design/translation.md). The two files are
  a pair sharing TestScratch's TranslationCallSites, so a check added to one
  goes in the other. The app's also pins the shadowing the split rests on.
- **They also fail a multi-argument phrase that does not number its arguments
  and the C-string specifier**, a crash rather than a wrong word, and render
  every counted form singular and plural: a form whose format key does not name
  its own sub-dictionary answers with the raw format.
- **They expect a large number of call sites**, so a scan that lost the source
  tree fails rather than passes. They read the file as text as well as parsed,
  to catch an entry written twice or left blank, and compare the source
  catalogue with the built one byte for byte, so a skip-build run after a
  catalogue change fails instead of passing on what is no longer there.
- **State that will not open, not just will not decode, is moved aside**, and
  one that cannot be moved is never saved over: StateFileTests and
  WorkspaceStoreTests+Restoring.
- **The user's git config cannot change what a read means**: GitRunnerTests
  reads the isolated keys back and watches an all-untracked worktree read dirty.
- **A tag sharing a branch's or the base's name decides nothing**:
  WorktreeCoordinatorMergesTests, its fixture merging by refname or git takes
  the tag. WorktreeGitBranchesTests holds the New Worktree sheet's names bare
  under the same tie.
- **Remove leaves a hook the user put in our own group**:
  AgentHookIntegrationMergingTests.
- **A poll reconciles without taking the keyboard, and a cross-group drop takes
  it with the tab**: AppModelWorktreeListRefreshTests and AppModelTabMovesTests.
- **A comma-decimal locale still sends a report that parses**:
  ShellIntegrationThroughHelperTests under a real zsh, pointing the user
  variable at an empty directory or the chain reaches the developer's own rc
  file.
- **The sidebar filter is not folded by the reader's alphabet**:
  SidebarListingTests reads the source, the current locale being process-wide
  and so not movable for one suite.
- **A tab id written twice keeps the copy whose worktree is still there**:
  WorkspaceRepairTests, the dead one listed first.
- **A notification type no build has heard of is taken to ask**:
  AgentHookIntegration+ReportsTests+Events.
- **What a failed accept means**: UnixSocketServer+AcceptOutcomeTests, the
  classification only.
- **Over the board, the menu's Open in Editor and New Worktree name no
  worktree**, no row drawing as selected there: AppModelEditorTests and
  AppModel+NewWorktreeSheetTests+Request.
- **Open in Editor leaves the board and refuses a busy worktree, and neither an
  escaped rename nor Use Shell Title is undone by the commit after it**:
  AppModelEditorTests and AppModelTabRenamingTests, against the model rather
  than the field.
- **A worktree path holding a newline is one worktree**:
  WorktreeGit+ListingTests against real git.
- **A comma-decimal locale gives bash a sane duration**:
  ShellIntegrationThroughHelperTests+Bash sets the clock variable by hand, which
  the system bash leaves unset.
- **Remove writes nothing to a file holding none of ours, and still takes back a
  half-written install**: AgentHookIntegrationInstallAndRemoveTests.
- **A repeat agent report writes nothing observable**:
  AppModelSessionReportsTests, through observation tracking.
- **The worker rules**: SessionStatesTests+BackgroundWorkers, with the roster
  kept by id, an older helper's count read as unnamed workers, and a worker's
  tool calls leaving the roster as it was.
- **A held stop leaves a failure alone** whether a worker's prompt covered it or
  it is still standing, so no failure is paid back as a Done:
  SessionStatesTests+WorkerPrompts.
- **A background shell is held for by pid and ended by its exit**:
  SessionStatesTests+BackgroundShells, and KernelProcessTableTests finds one
  among real children by its command line.
- **A resuming agent's Done is paid once**, by the woken turn or a cancelled
  last worker's end, never with a worker out: SessionStatesTests+ResumingAgents,
  and AppModel+SessionReportsTests+ResumingAgents from the report source up.
- **An agent dying with its shell announces nothing in either sweep order**:
  AppModelPIDWatchTests over twelve pairs, so a set's order meets both.
- **Each agent names a worker in its own spelling**:
  AgentHookIntegration+ReportsTests+Events. A start or stop naming nobody counts
  as an unnamed one: AgentHookEventTests.
- **A worker that is a conversation of its own is a worker, and its Stop is not
  the pane's Done**: AppModel+SessionReportsTests+CopilotWorkers, from captured
  payloads.
- **No value in a custom command or editor line is run**, inside the user's
  quotes or out: ShellLineTests under five real shells and each installed fish.
- **A hook variable renamed under hooks already written**: HookVariableTests.
- **The plugin follows a child session**: OpenCodePluginTests runs the generated
  JavaScript with spawn replaced, since a source test passes whatever it was
  rewritten to.
- **The chip reads the same roster on the row and on the card**, and a Done
  gives way to a worker and comes back once: AppModelSessionReportsTests.
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
- **The login environment is not known before its PATH has been scanned**:
  AppModelLoginEnvironmentTests, using the system shells file so the check is
  independent of which agents the machine has.
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
- **bash keeps its debug trap against one installed at the first prompt**,
  chains to both and hands the last status on:
  ShellIntegrationThroughHelperTests+Bash, real bash driven through a pipe so
  the prompt command runs between the two.
- **A PIPE trap set after the init survives the next report**, and **a refused
  relay's read loop ends with its shell** though a background child holds the
  pipe: HelperRelayTests under each installed bash.
- **git's own children are looked up on the login PATH**: GitRunnerTests,
  through an alias that runs a helper on a PATH of the test's own; the same
  runner without it fails, which is what makes the pass mean something.
- **A runner given only a search path runs the git on it**, and one named
  outright wins: GitRunnerTests. The default once ignored the path and ran the
  process's own.
- **A launched command is given no pipes**, so a shim holding the editor open
  holds no descriptors: ShellCommandTests.
- **A frame handed another session's surface asks that session for focus**:
  SurfaceFrameTests.
- **A duration no clock could have produced is dropped coming off the channel**:
  SessionStateReportBoundsTests and ElapsedTextTests, the trap being a
  conversion outside its range.
- **A branch name git will reject is refused before the pre-create hook**:
  AppModelWorktreeCreationTests, the rules themselves held against real git in
  GitBranchNameTests, the existing-branch path in
  WorktreeCoordinatorCreationTests.
- **A bare rebase that replayed nothing is not a landing**:
  WorktreeCoordinatorMergesTests, and ReflogWorkParserTests for the finish
  wording old and new.
- **A placeholder inside a value is not expanded again**: AgentFlagsTests.
- **A branch in a flag runs nothing on the way to the agent**: TabCommandTests
  under sh, zsh, bash and tcsh.
- **A promised drop's reader is called off the main actor**, as AppKit calls it:
  PromisedDropCollectorTests. A reader written as if on main died at the first
  file of every promised drop, which only a real drag shows. The drag itself
  cannot be staged, a promise being fulfilled through a drag session this
  process never gets.
- **An item promising two files is not delivered on the first**:
  PromisedDropCollectorTests. **Its files paste in the order it names them**,
  whatever order they land in: PromisedDropTests.
- **A live socket whose accept backlog is full is not taken for a dead one**:
  UnixSocketServerTests. The same suite starts a live server twice and fails a
  start, each time with a second process trying the claim, since a process's own
  record locks never conflict, and holds the path limit to the staging name's.
- **A request is answered on its own connection, a report or an unknown request
  never**: SocketMessageSourceTests. **An answer sent after the client's EOF
  still arrives, and one held open runs the client out of time, one that stops
  reading holds up no other, and one read slowly but steadily arrives whole past
  the timeout**: SocketReplyTests. **A request nobody reads runs out of time
  while still being sent, and a timeout under a second still runs out**:
  UnixSocketClientTests.
- **The command line reaches its own build's app**: HelperControlTests and
  PathsVariantTests, the latter also giving two worktree names that start alike
  files of their own; PathsStateFileCarryOverTests carries over a state file
  saved under the cut name from before the hash. **The installed tool is offered
  only over nothing, a dangling link or the shared one**: HelperLinkTests. **A
  link that cannot be made leaves the shell integration written**:
  AppLaunchFilesTests.
- **`open` launches the bundle the helper is in and waits for its answer**:
  HelperAppCommandsTests, through a stand-in for `/usr/bin/open` named by
  `MULTISHELL_OPENER`, a debug build's alone, since a test may not launch an
  app.
- **`multishell` in a pane is the helper, not the app**: SessionEnvironmentTests
  orders PATH, HelperHandOffTests the app's own hand-off, through a link to its
  executable too. **A login profile moving `/etc/paths` ahead leaves ours in
  front**: ShellIntegrationScriptsTests+LeadingPath under zsh, each bash and
  fish, and TabCommandTests for an agent's line through each login shell.
- **Each request does what its menu item or click does, and is refused rather
  than asked over a working agent**: the AppModelControl suites, the worktree
  and project ones on real git. Typing reaching a real shell needs the engine,
  so it was run by hand against a debug build on a scratch home (build.md), as
  were a pane's text read, the window and pane screenshots, and the settings
  windows' identifiers.
- **Two requests' alerts each answer their own request, and the user's comes
  back**: AppModelControlRequestAlertsTests, which also files nothing for an
  alert raised under a request that has answered.
- **A wait returns once the pane gets there and says how long it waited when it
  does not**: HelperPaneWaitingTests. **Following prints each new sample once
  and stops at the count**: HelperDebugSamplesTests, and AppModelDebugToolsTests
  numbers on from the last sample when the tools go off and on. **A screenshot
  is written by the helper**: HelperDebugScreenshotTests. **A find prints once
  the engine has counted**: HelperPaneFindingTests, and AppModelControlFindTests
  for the count's way from the engine to the model. Pressing Ctrl+C, a find's
  count and the menu were run by hand against a debug build.
- **A pane caught mid-resize is placed in a screenshot at its surface's own size
  from the top left**, as the layer shows it, not stretched:
  ViewScreenshotTests.
- **A key the command line presses types what that key types**:
  GhosttyKeyInputControlKeyTests, skipped rather than failed under any layout
  but US, its texts being that layout's.
- **The pid the helper reports stops short of the app**:
  HelperSessionEnvironmentTests with two real shell layers under the test
  process posing as the app; ProcessAncestryTests has the walk on its own.
- **The model's half**: AppModelSessionReportsTests, a report naming the app's
  pid tracking none, beside one from a subdirectory marking the deepest worktree
  containing it.
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
- **A worktree path holding a control character still reports from zsh**:
  ShellIntegrationThroughHelperTests. bash is not exercised, going through the
  helper, which encodes.
- **A user-set shell directory variable is followed**:
  ShellIntegrationScriptsTests+UserStartupFiles, a login interactive zsh under a
  fake home. Only a login shell reads the profile, so the login flag is what the
  test is.
- **It inherits no session or socket**: `Detached` hands the shell its whole
  environment, and run from a Multishell tab an inherited pair reported to the
  developer's live app.
- **An empty Enter under a user's prompt command starts no command**:
  ShellIntegrationScriptsTests+SessionReports.
- **A dead agent with a worker counted no longer holds Working**, and its
  shell's later failure is not an agent waiting on the badge:
  SessionStatesTests+BackgroundWorkers in both orders, AppModelDockBadgeTests
  with the board closed.
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
- **A greeting holding an equals sign does not cost the login shell its first
  variable**: EnvironmentDumpParserTests.
- **Numbers in an agent's settings file come back as written**, and a literal
  the grammar refuses or bytes that are not UTF-8 are still refused untouched:
  AgentHookFileTests.
- **A zero or non-finite split weight is refused on decode and on write**:
  PaneNodeDecodingTests and WorkspaceStoreTests.
- **A real surface is made only where its lifetime or libghostty's own callback
  is the question**, on `/bin/sleep` and in no window on screen: the runtime
  outliving it, a closed session staying silent, the pane monitor's two events,
  and a clicked link reaching the delegate after libghostty's click returns,
  resolved in the pane's reported directory (GhosttySurfaceViewTests,
  GhosttyTerminalHostTests, GhosttyPaneEventMonitorTests). A failed expectation
  on a pane is read into a Bool first, as describing one trips over AppKit's
  cursors, null pointers in a test process. What libghostty is handed is
  otherwise tested as values: the key, modifier and mouse button mapping
  (GhosttyKeyInputTests, GhosttyModifiersTests, GhosttyMouseButtonTests), split
  surrogates (GhosttySurrogatePairingTests), the actions decoded
  (GhosttySurfaceEventTests), the launch's C strings
  (GhosttySurfaceLaunchTests), the clipboard and a program's reads of it
  (PanePasteboardTests, GhosttyClipboardContentsTests,
  GhosttyClipboardAnswerTests) and the unsafe paste question
  (GhosttyPasteConfirmationTests). Secure keyboard entry's balance against a
  fake system switch is GhosttySecureInputTests. Focus kept in step with the
  window is not: libghostty's own idea of it shows only on a live surface.
- **Under `make test` a surface's command never runs**: libghostty starts it
  through `/usr/bin/login`, setuid, which the sandbox refuses with `EPERM`. So a
  link clicked in a pane is tested from the event on (GhosttySurfaceEventTests,
  GhosttyLinkRuleTests, GhosttyLinkPathTests, GhosttyLinkClicksTests,
  GhosttyTerminalHostTests); that libghostty sends the event for a Cmd+click was
  seen by hand at `ad97d33`.
- **A config file outliving its load, and the line a diagnostic names**:
  GhosttyLoadedConfigTests, against the real libghostty.
- **What a zsh prompt tells the terminal now the engine's integration is off**,
  a command's end and status, the directory, the title and the cursor shape in
  each keymap, each only where the user's features ask:
  ShellIntegrationScriptsTests +PromptMarks, +DirectoryReports, +Title and
  +CursorShape, run through +ZshOutput, which loads zle by hand for the keymap
  hooks a piped shell would not register. bash's marks, directory and title run
  through +BashOutput, and fish's cursor through +FishOutput.
- **bash launched as libghostty launches a command**, `exec -l`, still reading
  our init file: EngineCommandLineTests.
- **`sudo` and `ssh` wrapped only where the user's features ask, and a `sudo`
  function of their own kept**: ShellIntegrationScriptsTests +CommandWrappers,
  the bash half under `InstalledBashes.all` and the fish half under
  `InstalledShells.fishes`.
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
- **A find bar is its pane's own and ends with its pane**: AppModelFindTests.
- **The steps' engine spellings**: GhosttySearchActionsTests, the crossed next
  included; their shortcuts being taken from the surface and every unbind line
  accepted by the pinned engine are GhosttyUnbindsTests.
- **A watcher tick re-reading every project**: AppModelWorktreeListRefreshTests.
- **A CRLF Ghostty file read as one line, a config file name Ghostty reads and
  we do not, and an include left unfollowed**: GhosttyUserConfigTests.
- **Emptying the sidebar filter leaves the field up, and only closing hands the
  keyboard back**: AppModelSidebarFilterTests.
- **A project collapsed under the filter stays collapsed until the text changes,
  and its rows are read once it opens**: AppModelProjectExpansionTests and
  AppModel+StatusReadsTests+VisibleRows. SidebarViewTests holds the chevron to
  it by pixels.
- **A header badge ringed in the sidebar's colour**: WorktreeHeaderTests.
- **A worktree on a volume that does not answer is refused without waiting on
  it, and asked once**: AppModelWorktreeSelectionTests.
- **The xcrun shim is looked past, and xcrun never asked with no developer
  directory**: GitExecutableTests.
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
- **A row TextKit 2 lays out away from where its number says**:
  DiffDocumentViewTests and SplitDiffDocumentViewTests, over 10,000 rows jumped
  to from the end, the only check on an override Apple does not document
  (design/files.md). **A file tab painting outside its frame**:
  DiffDocumentViewTests+Clipping, by pixels.
- **A state file with file tabs read by the build before them keeps this build's
  terminal order, and one that build wrote takes its order from `tabs`**:
  WorkspaceStoreTests+FileTabs and Workspace+RepairTests+FileTabs.
- **A grammar bump whose query no longer compiles, or whose bundle is not
  found**: HighlightGrammarsTests, every grammar against its query.
- **A `<script>`, `<style>` or Svelte expression left plain or coloured in the
  wrong language**: HighlightInjectionsTests and its +Svelte, +ElementAttributes
  and +AttributeInjections suites, ElementBodyLanguageTests and
  SvelteBlockHeadTests. **A `>` or bare `&` in Svelte text leaving the rest of
  the file uncoloured**: SvelteGrammarInputTests and SyntaxHighlighterTests.
- **A drag nothing takes or a drop refuses goes back between the neighbours it
  left, and one a drop took stays**: AppModelTabDragTests.
- **A segmented picker drawn only as wide as its labels**:
  ViewSegmentedAcrossRowTests.
- **The close guard and the quit alert count only an agent's Working**, so a
  plain command asks nothing: AppModelSessionReportsTests and
  AppModelTabClosingTests.
- **A misspelt option in a hook line is a usage error** for every reporting
  command, not a value read under another name: HelperTests.
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

## Conventions

- **A new file goes in the folder its subject is in** (layout.md), and a value's
  `<Type>+Sample.swift` builder stays at the suite's root with the harnesses.
- **Git behaviour goes against a real repository**, never mocks:
  RepositoryFixture, a bare clone with worktrees beside it included. FakeGit
  only for what real git cannot do on demand. Parsers get fixture text, odd
  lines included.
- **Real git comes from a fixture whose runner turns commit signing off**, or a
  developer whose global config signs would be asked for the key once per
  fixture commit. It rides on the runner, so a clone needs no step of its own.
- **A fixture's `WorktreeGit` skips the wait before a new index is written**,
  `settlesNewIndex: false`, or each of the suites' hundreds of creates waits a
  second. The three tests about that wait keep it on, one each in
  WorktreeCoordinatorCreationTests, WorktreeCoordinatorStoppedAddTests and
  WorktreeGitCreationTests.
- **Claude's subagent hooks replay from captured runs** in
  `Tests/MultishellAppCoreTests/Fixtures/ClaudeHookCaptures`, through
  SessionStatesTests+ClaudeCapture. Hand-written payloads held only the order we
  expected. Claude sends SubagentStop at every pause of a subagent as well as
  its end, and each hook is its own process, so one run logged the main agent's
  prompt from a hand-back before the stop of the worker that handed back.
- **A capture is one payload a line**, cut to the fields the helper reads, the
  transcript path left as `TRANSCRIPT` and each `meta.json` written after the
  worker's first start, as Claude writes it. A new run is captured by
  `claude --settings` naming a hook that appends its stdin to a file, never the
  user's own settings; it appends under `lockf`, as two hooks at once
  interleaved a line.
- **A view is tested only for its size or its pixels**, laid out in a window
  never ordered in; a value a view reads is tested as a value.
- **Prefer evidence to a clock.** Concurrency is read off what the children
  recorded about each other, not off how long the batch took; both were
  wall-clock bounds first, and both flaked. Wait for a state with `waitUntil` in
  TestScratch and assert after it; a fixed sleep fails on a loaded runner and
  wastes time on a quiet one.
- **A bound that is left tells one outcome from another**, not a fast machine
  from a slow one: the child sleeps far longer than the bound, so what fails it
  is the stop never arriving. Never size a bound to a measured figure plus
  headroom; the runner's mood decides that.
- **A test that reads something process-wide is reading the other suites too.**
  Take the lowest of several samples rather than one reading, and expect to
  revisit it when a test that spawns in bulk arrives.
- **A test never hands the stopper or a pid watch a pid it reaped**: tests run
  in parallel, and the pid can go to another test's child, which the stop would
  then hang up and the watch find alive. `deadPID()` in TestScratch gives one
  past PID_MAX instead.
- **Nothing on the cooperative pool waits for something only another task can
  release.** The pool is as wide as the cores.
  `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` cuts it to one thread, which turns
  such a wait into a hang on any machine.
- **At most one test runs per core**, through `Scripts/one-test-per-core.sh` in
  `make test` and CI. Without it, CI froze with all 1,550 tests started within
  1.4 s and none finished. A swift-testing from before the cap
  (swift-testing#1390) fails the script rather than running uncapped.
- **A debug-tools test turns them on with `enableDebugTools`**, which pushes the
  sampling tick out to an hour and stands in a process scan, and takes each
  sample itself with `takeDebugSample`. A live tick would race the test's own
  sample, and the real scan reads whatever the machine is running.
- **A fake git that waits on a gate file also stops once the scratch root is
  gone** wherever the read can outlive the test: one started after teardown
  finds no gate to wait for and would spin for good, as the hung-read tests in
  AppModel+WorktreeRemovalRequestTests+StatusReads show.
- **Never the developer's machine**: a shell runs against a home the test wrote,
  the model's login environment comes from the harness, detection runs against
  fake executables on a fake PATH, and git is the fixture's runner rather than
  the PATH's.
- **No test writes outside the build tree and the temporary directories**: a
  suite once took the Claude hooks out of the developer's own settings, and an
  interactive shell rewrote their zsh history. `make test`'s sandbox enforces it
  only there (build.md), so a test names every file it writes.
  `homeDirectoryForCurrentUser` ignores `$HOME`, so the agents' files are
  reached through an injected path or `$HOME`, never the account's; a model the
  harness builds stubs every launch write.
- **A shell given this process's environment takes `Scratch.shellEnvironment`**,
  which empties `HISTFILE`: an exported one had an interactive bash append the
  tests' commands to the developer's own zsh history. `ShellCommand`'s scripts
  and the login capture empty it themselves, but its `runUncaptured` keeps it
  for the editor; a test starting bash or ksh through that or any other way must
  empty it too, or it truncates or rewrites that history.
- **A hook or the login capture leaves a named history file alone**:
  ShellCommandTests+HookShells under bash, sh and ksh, and
  LoginShellEnvironmentTests.
- **An interactive shell starts through `Detached.output`**, never `Process`:
  `Process` hands on the terminal `make test` runs under, and a shell outside
  its foreground group stops itself on SIGTTIN, with no timeout to end it. The
  runner starts every child the same way (dependencies.md).
- **A bash behaviour runs under every installed bash**, `InstalledBashes.all` in
  TestScratch: the system's 3.2 and a newer one differ in `$!`, `wait` and, from
  5.3, how the PIPE trap is read.
- **A fish behaviour runs under each installed fish**, `InstalledShells.fishes`
  in TestScratch. macOS ships no fish, so a machine without Homebrew's drops
  those cases rather than failing them, and CI installs none.
- **Every scratch directory and socket is removed** by the test or its harness,
  and the socket helper takes the claim file the server keeps.
- **A helper command that could reach the app names its socket in
  `MULTISHELL_CONTROL_SOCKET`**: ControlListener's `environment`, or a path
  nobody holds. Without it a debug helper outside a bundle asks the plain debug
  build's socket in the account's Application Support, which the developer's own
  debug app may hold. `HelperBinary.run` names one nobody listens on, for both
  the control and the report socket, wherever a test names none, so a usage
  error that stops being one fails the test instead of reaching that app.

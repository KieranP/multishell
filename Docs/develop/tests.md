# Tests

What each test catches, and the conventions a new one follows. `Docs/design/`
says why these are the rules.

## What catches a breach of the rules

- **Persisted defaults, unknown enum values included**: DecodingDefaultsTests.
- **An old state file still loads with what it said**: TabGroupMigrationTests
  reads a real pre-columns file, NotificationPreferenceMigrationTests the picker
  this build replaced with toggles.
- **The workspace invariants and the reference repair**:
  WorkspaceStoreTests+Invariants and AppModelInvariantTests, random operations,
  printing the failing seed and step.
- **No blocking in the core**: ProcessRunnerTests runs several children per core
  and reads off what each saw running beside it, starved being a thread per core
  at the ceiling.
- **Blocking work sent off the main actor leaves the cooperative pool**:
  OffMainTests holds one more `offMain` call than there are cores and still
  releases them all from a task.
- **At least four children per core, and 96, counted, not timed**: a wall-clock
  bound was the runner's mood, and no figure both had headroom on one core and
  caught twelve starving. Starved, at most a thread per core is inside a run;
  unstarved, nearly all are, the hold being long against a launch.
- **Descriptor exhaustion** lowers the process-wide limit, so
  DescriptorExhaustionTests needs its environment flag and a filter.
- **Git on a timer reads only**: WorktreeGitStatusTests.
- **A tree still being built wears no badge, and a stage on a listed worktree
  keeps the one it earned**: the badged tests in
  AppModelGitTests+StatusWhileBuilding and the merged-badge one in +Merges, on
  real git with a gated hook.
- **Git against real repositories**, bare clone with worktrees beside it
  included: RepositoryFixture. FakeGit only for what real git cannot do on
  demand.
- **Detection runs against fake executables on a fake PATH**, never the machine.
  Hooks run through real shells under a substitute home.
- **A shortcut's two spellings agree and the clipboard ones stay with the
  terminal**: AppShortcutTests, pinned against the config the engine was given.
- **Identifiers spelled in both Swift and the generated Info.plist still
  match**: BundleDeclarationTests, reading the template out of the checkout.
  Nothing at build or run time notices these having parted.
- **The quit alert answers both keys under any language**: AppDelegateTests,
  which builds it with translated titles, AppKit binding Escape by matching the
  English one.
- **A removal button keeps its red bezel and its Return**:
  DestructiveAlertTests, AppKit taking the key off at every layout and drawing a
  default button in the accent colour. What a presented sheet actually draws is
  not testable here, so the suite holds the properties, bar macOS 27's alert
  button, which keeps no bezel colour: there the offscreen drawing is read.
- **Each override binds to its own setting**: AppModelSettingsBindingsTests, the
  override accessors taking the same arguments and returning the same type.
- **Sidebar counts agree with the columns they summarise**:
  AppModelAgentBoardTests over every state and both filter positions, the counts
  being made without building a card. A pane whose reported agent has exited is
  a shell to the counts, the cards and the strip alike, the four having once
  asked apart.
- **An agent mark that draws nothing**: AgentMarkShapeTests parses every mark
  and holds each to its square, a file that will not parse being left out of the
  table rather than crashing a view.
- **An agent typed at a prompt that marks nothing**: the placeholder test in
  ShellLaunchTests holds the generated files to naming the agents, and
  PromptMarkTests runs the real shells and reads what they report.
- **That zsh test caught a word subscript taking characters** for a command run
  by its path, which a syntax check cannot see.
- **A settings page outgrowing its fixed window**: SettingsPageSizeTests lays
  each page out in a window never ordered in and holds it to the window's
  height. The tab band takes none of it there, the content being given the whole
  window.
- **The bound is absolute, not a margin**: Project General sits 18.5 pt under
  it, so a macOS that grows a grouped form's rows fails this first, rightly.
  Project Agents measured 541 here and 539 on the CI runner. Appearance stays
  in: its font list is the machine's, but a picker is one row however long.
- **A page in parts is held part by part**: Project Hooks' three stages and
  Agents' Agent part. Hooks' Create stage under a repository file asking for
  trust is its tallest, 593 pt of the 600.
- **One part is exempt and says why**: Agents' Hooks part reads the machine on
  appear, so its height is the developer's. Width is not checkable at all, a
  minimum-size measurement reporting where text wraps.
- **A tab strip that stops answering the wheel**: SidewaysWheelViewTests sends a
  synthesized vertical scroll to the overlay over a real scroller and waits for
  the offset to move, the run loop spun by hand: `run(until:)` returns at once
  while it has no source.
- **Its control is the same event handed straight to the scroller**, which moves
  it by nothing: that is why the catcher exists. ViewSidewaysWheelTests holds
  the other half, the marked scroller being the strip's and the catcher being
  outside it.
- **A word on screen with no translation, or a translation nothing shows**:
  TranslationTests reads every lookup off the source and checks the keys both
  ways, one per catalogue over its own half.
- **The two TranslationTests files are a pair**, the app's suite reaching no
  shared target keeping their scanners apart; a check added to one goes in the
  other.
- **The app's also pins the shadowing the split rests on**, and that the words
  written in both catalogues read the same, which the libraries cannot check,
  not knowing a frontend exists.
- **Each counts a call's arguments against its phrase**, fails a multi-argument
  phrase that does not number them, and refuses the C-string specifier, which
  would be a crash rather than a wrong word.
- **Every counted form is rendered singular and plural**, a form whose format
  key does not name its own sub-dictionary answering with the raw format.
- **It expects a large number of call sites**, so a scan that has lost the
  source tree fails rather than passes, and it reads the file as text as well as
  parsed, to catch an entry written twice or left blank.
- **It compares the source catalogue with the built one byte for byte**, so a
  skip-build run after changing the catalogue says so instead of passing on what
  is no longer there.
- **State that will not open, not just will not decode, is moved aside**, and
  one that cannot be moved is never saved over: PersistenceTests.
- **The user's git config cannot change what a read means**: GitRunnerTests
  reads the isolated keys back and watches an all-untracked worktree read dirty.
- **A tag sharing a branch's or the base's name decides nothing**:
  WorktreeCoordinatorMergesTests ties a tag to a merged branch, its fixture
  merging by refname or git takes the tag, and one to each form of the base.
- **Remove leaves a hook the user put in our own group**:
  AgentHookCatalogueTests.
- **A poll reconciles without taking the keyboard, and a cross-column drop takes
  it with the tab**: AppModelGitTests and AppModelTabsTests, both reading the
  fake engine's recorded focus.
- **A comma-decimal locale still sends a report that parses**:
  HelperShellIntegrationTests under a real zsh, pointing the user variable at an
  empty directory or the chain reaches the developer's own rc file.
- **The sidebar filter is not folded by the reader's alphabet**:
  SidebarFilterTests reads the source, the current locale being process-wide and
  so not movable for one suite.
- **A tab id written twice keeps the copy whose worktree is still there**:
  WorkspaceRepairTests, the dead one listed first.
- **A notification type no build has heard of is taken to ask**:
  AgentHookPayloadTests.
- **What a failed accept means**: UnixSocketServerTests+AcceptOutcome, the
  classification only.
- **Over the board, the menu's Open in Editor and New Worktree name no
  worktree**, no row drawing as selected there: AppModelLaunchTests and
  NewWorktreeRequestTests.
- **Open in Editor leaves the board and refuses a busy worktree, and an escaped
  rename is not undone by the commit after it**: AppModelLaunchTests and
  AppModelTabsTests, both against the model rather than the field.
- **A worktree path holding a newline is one worktree**: WorktreeGitTests+Paths
  against real git, the parser's fixtures NUL-separated through a converter so
  they stay readable.
- **A comma-decimal locale gives bash a sane duration**:
  HelperShellIntegrationTests sets the clock variable by hand, which the system
  bash leaves unset.
- **Remove writes nothing to a file holding none of ours, and still takes back a
  half-written install**: AgentHookCatalogueTests.
- **A repeat agent report writes nothing observable**:
  AppModelSessionReportsTests, through observation tracking.
- **The worker rules**: SessionStatesTests+BackgroundWorkers, with the roster
  kept by id, an older helper's count read as unnamed workers, and a worker's
  tool calls leaving the roster as it was.
- **A held stop leaves a failure alone** whether a worker's prompt covered it or
  it is still standing, so no failure is paid back as a Done:
  SessionStatesTests+BackgroundWorkers.
- **A background shell is held for by pid and ended by its exit**:
  SessionStatesTests+BackgroundShells, and ProcessAncestryTests finds one among
  real children by its command line.
- **A resuming agent's Done is paid once**, by the woken turn or the deadline,
  never with a worker out: SessionStatesTests+ResumingAgents, and
  AppModelSessionReportsTests through the socket with the banner counted.
- **An agent dying with its shell announces nothing in either sweep order**:
  AppModelSessionReportsTests over twelve pairs, a set's order meeting both.
- **Each agent names a worker in its own spelling**: AgentHookPayloadTests. A
  start or stop naming nobody counts as an unnamed one: AgentHookCatalogueTests.
- **A worker that is a conversation of its own is a worker, and its Stop is not
  the pane's Done**: CopilotWorkerTests, captured payloads driven through the
  helper's report into the model.
- **No value in a custom command or editor line is run**, inside the user's
  quotes or out: CustomLineShellTests under five real shells.
- **The plugin follows a child session**: OpenCodePluginTests runs the generated
  JavaScript with spawn replaced and reads back what the helper would have been
  called with, a source test passing whatever it was rewritten to.
- **The chip reads the same roster on the row and on the card**, and a Done
  gives way to a worker and comes back once: AppModelSessionReportsTests,
  through the socket, the banner counted.
- **Export keeps a hook the user refused** and does not trust it into the
  bargain, and keeps the directory and path lists an unanswered file holds:
  AppModelHookControlTests, against the real file on disk.
- **The trust answer travels to the new digest**: the same suite trusts a file
  whose directory confinement refuses, exports, and asks whether the hook still
  runs.
- **A symlink planted after the file was read is caught**: the same suite
  watches the create refuse the directory rather than check out through it.
- **What the app cannot read is written back as it was**:
  SharedProjectSettingsTests over an unknown key, a nested one, an order no
  build names and a wrong-typed flag.
- **A stage ending while the board is up leaves it up**, and the first tab opens
  under the create settings wherever the user is looking, without moving the
  selection or the keyboard: AppModelHookControlTests.
- **The login environment is not known before its PATH has been scanned**:
  AppModelAgentsTests, using the system shells file so the check is independent
  of which agents the machine has.
- **A status answering after its worktree went badges nothing**:
  AppModelGitTests, real git, the store emptied between the ask and the answer.
- **A focus report that changes nothing writes nothing**: WorkspaceStoreTests,
  through observation tracking, a re-read of a repository's file held to the
  same rule. Its counter counts store operations rather than writes.
- **Only a repository's file lists are held to the checkout**:
  WorktreeFilesTests gets a user's home and absolute entries back as skipped,
  with no failure raised.
- **Neither end is a licence to write outside the worktree**: the same suite
  points a user's entry at a parent path, with the worktree nested so the
  mirrored destination is genuinely elsewhere, and finds nothing written.
- **bash keeps its debug trap against one installed at the first prompt**,
  chains to both and hands the last status on: HelperShellIntegrationTests, real
  bash driven through a pipe so the prompt command runs between the two.
- **A PIPE trap set after the init survives the next report**, and **a refused
  relay's read loop ends with its shell** though a background child holds the
  pipe: HelperShellIntegrationTests under each installed bash, the loop's pid
  noted by a stand-in helper that refuses `relay`.
- **git's own children are looked up on the login PATH**: GitRunnerTests,
  through an alias that runs a helper on a PATH of the test's own; the same
  runner without it fails, which is what makes the pass mean something.
- **A runner given only a search path runs the git on it**, and one named
  outright wins: GitRunnerTests, with stand-in gits that say which ran. The
  default once ignored the path and ran the process's own.
- **A launched command is given no pipes**, so a shim holding the editor open
  holds no descriptors: ShellCommandTests asks the shell whether its own output
  is a pipe.
- **A frame handed another session's surface asks that session for focus**:
  SurfaceFrameTests, in a window never ordered in.
- **A duration no clock could have produced is dropped coming off the channel**:
  SessionStateReportTests and ElapsedTextTests, the trap being a conversion
  outside its range.
- **A branch name git will reject is refused before the pre-create hook**:
  AppModelHookControlTests, the rules themselves held against real git over a
  table in GitRefNameTests, the existing-branch path in WorktreeCreationTests.
- **A bare rebase that replayed nothing is not a landing**:
  WorktreeCoordinatorMergesTests against real git, beside the fast-forward case
  it mirrors, and ReflogWorkParserTests for the finish wording old and new.
- **A placeholder inside a value is not expanded again**: AgentFlagsTests.
- **A branch in a flag runs nothing on the way to the agent**: TabCommandTests
  under sh, zsh, bash and tcsh.
- **A promised drop's reader is called off the main actor**, as AppKit calls it:
  PromisedDropCollectorTests. A reader written as if on main died at the first
  file of every promised drop, which only a real drag shows. The drag itself
  cannot be staged, a promise being fulfilled through a drag session this
  process never gets.
- **An item promising two files is not delivered on the first**:
  PromisedDropCollectorTests.
- **A live socket whose accept backlog is full is not taken for a dead one**:
  UnixSocketServerTests, the queue blocked and the backlog filled by hand.
- **The same suite starts a live server twice** and has a second process try the
  claim, a process's own record locks never conflicting, and holds the path
  limit to the staging name's.
- **The pid the helper reports stops short of the app**: HelperTests with two
  real shell layers under the test process posing as the app;
  ProcessAncestryTests has the walk on its own.
- **The model's half**: AppModelSessionReportsTests, a report naming the app's
  pid tracking none, beside one from a subdirectory marking the deepest worktree
  containing it.
- **Removing the main worktree is refused before the hook and the Trash**:
  AppModelHookControlTests. Without the guard that test bins the fixture.
- **Removing one worktree leaves the record of another whose directory is
  away**, and a Trash that refuses leaves a lock and its reason in place:
  WorktreeGitRemovalTests, against real git.
- **A Trash that takes nothing stops the removal there**, the forget being what
  would unlink a directory still in place: the same suite.
- **A refused create leaves no container directory**: WorktreeCreationTests.
- **A branch lookup that failed is not a new branch**, so a stopped create
  deletes nothing: WorktreeCreationTests on a fake git exiting 128.
- **A read-only directory copies whole and keeps its modes**:
  WorktreeFilesTests, a nested 0555 tree.
- **A checkout git refuses to read is still removed with its hooks, and a locked
  stale record is forgotten**: WorktreeGitRemovalTests, the first on a fake git
  failing only inside the checkout.
- **Launch opens terminals without waiting on the dropped-file sweep**:
  AppModelTests, the sweep held open by a gate.
- **A row the filter shows is polled, and a slow one is read before its removal
  dialog**: AppModelGitTests+VisibleRows and +RemovalReads.
- **A row on screen is read before its dialog too, a pause in typing reads only
  the rows the filter brought back, a late removal read leaves the dialog up and
  a repeated click reads once**: the same suite, the last two on a fake git
  holding one read open.
- **A row the poll is reading is not read again, but a prompt's refresh asked
  for meanwhile is read once it lands**: AppModelGitTests, a fake git holding
  the first read open.
- **A confirmed removal trashes or deletes as its dialog said**, though the
  setting changed while it was up: AppModelGitTests.
- **The Trash is asked off the main thread**: AppModelHookControlTests, the fake
  Trash recording the thread of each call.
- **A worktree path holding a control character still reports from zsh**:
  HelperShellIntegrationTests, and every line the socket received must parse.
  bash is not exercised, going through the helper, which encodes.
- **A user-set shell directory variable is followed**:
  HelperShellIntegrationTests, a login interactive zsh under a fake home. Only a
  login shell reads the profile, so the login flag is what the test is.
- **Its session and socket variables are blanked**: the runner merges over the
  process's own, and run from a Multishell tab the hooks reported to the
  developer's live app.
- **An empty Enter under a user's prompt command starts no command**:
  PromptMarkTests, real bash with a logging stand-in for the helper, counting
  the started lines.
- **A dead agent with a worker counted no longer holds Working**, and its
  shell's later failure is not an agent waiting on the badge:
  SessionStatesTests+BackgroundWorkers in both orders, AppModelAgentBoardTests
  with the board closed.
- **A hook still running when its worktree is removed in a terminal is ended**:
  AppModelHookControlTests, a sleeping hook, the row removed with real git,
  bounded and with no alert.
- **The ownership rules those rest on**: WorktreeWorkInFlightTests on the plain
  value, a stop handle dropped only by the stage that installed it, a claim
  counted, and only the newest create answering the sheet's Cancel.
- **A failing refresh landing after its project was removed dims nothing**:
  AppModelGitTests, a fake git that waits for a file before failing.
- **A record git will neither remove nor prune after the Trash took the
  directory is its own failure**: GitIntegrationTests on a fake git,
  RemovalFailureTests for the mapping.
- **A prune that leaves the record listed is still a failure**, and an
  unreadable or empty list counts as listed: the same suite, a fake git whose
  remove fails and whose list still names the path.
- **A greeting holding an equals sign does not cost the login shell its first
  variable**: LoginShellEnvironmentTests, on the parser alone.
- **Numbers in an agent's settings file come back as written**, and a literal
  the grammar refuses or bytes that are not UTF-8 are still refused untouched:
  AgentHookCatalogueTests over both sets.
- **A zero or non-finite split weight is refused on decode and on write**:
  DecodingDefaultsTests and WorkspaceStoreTests.
- **A view is tested only for its size or its pixels**, laid out in a window
  never ordered in; a value a view reads is tested as a value.
- **The terminal host against a real shell is untested**: a surface needs a
  window and a GPU, so the only suite that builds the host is
  GhosttyTerminalHostTests, which opens no surface.
- **A removal dialog left up for a worktree git no longer lists, and Remove
  offered on the main worktree**: AppModelGitTests and AppModelTests, both
  through the one place each is decided.
- **A second copy of the app writing the workspace file**: AppModelTests hands
  the fake state source an in-use socket and expects the platform asked to hand
  over, no poll started, and no file after a change.
- **Two saves landing out of order**: WorkspaceStoreTests+OrderedSaves prepares
  two, runs the later first, and expects the file to hold it.
- **A stalled write holding the main actor**: SaveOrderTests holds one inside
  `land` and asks for a ticket and whether one landed from another thread.
- **Two exports landing out of order, and a poll between an export's write and
  its finish**: SharedSettingsExportTests, the same way, on real git, the second
  also finishing before the first.
- **What the git badge counts**: DiffStatParserTests and
  UntrackedLineCounterTests on fixture text and scratch files, the rows that
  carry no line among them, a symlink that is never followed, a file that would
  cross the budget, and the files past the cap.
- **The three together on real git**: GitIntegrationTests, once per indicator
  setting, plus an untracked directory that is one entry whose lines are still
  counted and a real merge conflict that is no file with no lines.
- **A repository whose own config says not to look at untracked files**:
  GitRunnerTests, where the lines are counted anyway.
- **Changing the indicator reads every badge at once**: AppModelGitTests, and a
  read started before the change badges nothing, held open by a fake git until
  the read that replaced it has landed.
- **The status poll asking a missing project or a slow checkout**:
  AppModelGitTests on a fake git, counting the calls, once more for a prompt's
  own refresh of that slow worktree, and once for a read discarded mid-flight,
  which must leave the next read due.
- **The pacing rule itself**: StatusPollPaceTests, and StatusReadLogTests for
  the readings it is applied to, the generation and which read holds a row
  included. Every other model test runs unpaced, or a read right after a change
  would be skipped.
- **A find bar is its pane's own and ends with its pane**: AppModelFindTests
  through the fake engine's recorded searches, over the disabled items, the
  second worktree, the arrows, the keyboard hand-back and the repeat needle.
- **The steps' engine spellings**: GhosttySearchActionsTests, the needle alone
  and the crossed next; their shortcuts being taken from the surface and every
  unbind line accepted by the pinned engine are AppShortcutTests.
- **A watcher tick re-reading every project**: AppModelGitTests adds a second
  repository, adds a worktree to it behind the app's back, and ticks with the
  first project's directory.
- **A CRLF Ghostty file read as one line, a config file name Ghostty reads and
  we do not, and an include left unfollowed**: GhosttyUserConfigTests, against
  scratch files.
- **Emptying the sidebar filter leaves the field up, and only closing hands the
  keyboard back**: AppModelSidebarFilterTests, through the fake engine's
  recorded focus.
- **A worktree on a volume that does not answer is refused without waiting on
  it, and asked once**: AppModelTests, through a stat that blocks until
  released.
- **The xcrun shim is looked past, and xcrun never asked with no developer
  directory**: GitExecutableTests.
- **The merge reads' round budget and their one shared width**:
  MergeReadLogTests on the log, AppModelGitTests+Merges for a lone project's
  refresh, and WorktreeCoordinatorMergesTests+ReadWidth counting a fake git's
  cherry processes across two projects.
- **A child with a terminal to stop it, or ended by its task's cancel**:
  ProcessRunnerTests reads a background grandchild's session id, and cancels the
  task awaiting a child that then finishes.
- **A spawn that forks the app to get that session**: ProcessRunnerTests counts
  the atfork handler's calls, which `posix_spawn` never makes. Anything else in
  the test process that forks would fail it.
- **A drag nothing takes or a drop refuses goes back between the neighbours it
  left, and one a drop took stays**: AppModelTabDragTests, through the model.
- **A segmented picker drawn only as wide as its labels**:
  SegmentedPickerWidthTests, in a window never ordered in.

## Conventions

- **A new file goes in the folder its subject is in**, one tree mirroring the
  other (layout.md). Harnesses and fakes stay at the suite's root.
- **Git behaviour goes against a real repository**, never mocks. Parsers get
  fixture text, odd lines included.
- **Prefer evidence to a clock.** Concurrency is read off what the children
  recorded about each other, not off how long the batch took. Both were
  wall-clock bounds first, and both flaked.
- **A test never hands the stopper a pid it reaped**: tests run in parallel, and
  the pid can go to another test's child, which the stop would then hang up.
  ProcessStopTests uses a pid past PID_MAX for the reaped case.
- **Nothing on the cooperative pool waits for something only another task can
  release.** The pool is as wide as the cores.
  `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1` cuts it to one thread, which turns
  such a wait into a hang on any machine.
- **At most one test runs per core**, through `Scripts/one-test-per-core.sh` in
  `make test` and CI. Without it, CI froze with all 1,550 tests started within
  1.4 s and none finished. A swift-testing from before the cap
  (swift-testing#1390) fails the script rather than running uncapped.
- **Waiting for a state is the shared helper**, with the assertion after it; a
  fixed sleep fails on a loaded runner and wastes time on a quiet one.
- **Never the developer's machine**: a shell runs against a home the test wrote,
  the model's login environment comes from the harness, and git is the fixture's
  runner rather than the PATH's.
- **A shell given this process's environment takes `Scratch.shellEnvironment`**,
  which empties `HISTFILE`: an exported one had an interactive bash append the
  tests' commands to the developer's own zsh history. `ShellCommand`'s scripts
  and the login capture empty it themselves, but its `launch` keeps it for the
  editor; a test starting bash or ksh through that or any other way must empty
  it too, or it truncates or rewrites that history.
- **An interactive shell starts through `Detached.output`**, never `Process`:
  `Process` hands on the terminal `make test` runs under, and a shell outside
  its foreground group stops itself on SIGTTIN, with no timeout to end it. The
  runner starts every child the same way (dependencies.md).
- **A hook or the login capture leaves a named history file alone**:
  ShellCommandTests+HookShells under bash, sh and ksh, and
  LoginShellEnvironmentTests.
- **No test writes outside the build tree and the temporary directories**: a
  suite once took the Claude hooks out of the developer's own settings, and an
  interactive shell rewrote their zsh history. `make test` enforces it with a
  sandbox that refuses every other write, but it holds only there, so a test
  names every file it writes. `homeDirectoryForCurrentUser` ignores `$HOME`, so
  the agents' files are reached through an injected path or `$HOME`, never the
  account's; a model the harness builds stubs every launch write.
- **Every scratch directory and socket is removed** by the test or its harness,
  and the socket helper takes the claim file the server keeps.
- **A bound that is left tells one outcome from another**, not a fast machine
  from a slow one: the child sleeps far longer than the bound, so what fails it
  is the stop never arriving.
- **Do not size a bound to a measured figure plus headroom**; the runner's mood
  decides that. The test lock across worktrees is for the same reason, and a
  bare test run takes none.
- **A test that reads something process-wide is reading the other suites too.**
  Take the lowest of several samples rather than one reading, and expect to
  revisit it when a test that spawns in bulk arrives.
- **Real git comes from a fixture whose runner turns commit signing off**, or a
  developer whose global config signs would be asked for the key once per
  fixture commit. It rides on the runner, so a clone needs no step of its own.
- **A fixture's `WorktreeGit` skips the wait before a new index is written**,
  `settlesNewIndex: false`, or each of the suites' hundreds of creates waits a
  second. WorktreeCreationTests keeps it on for the two tests about that wait.

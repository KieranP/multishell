# Tests

What each test catches, and the conventions a new one follows. `Docs/design/`
says why these are the rules.

## What catches a breach of the rules

- **Persisted defaults, unknown enum values included**: DecodingDefaultsTests.
- **An old state file still loads with what it said**: TabGroupMigrationTests
  reads a real pre-columns file, NotificationPreferenceMigrationTests the picker
  this build replaced with toggles.
- **The workspace invariants and the reference repair**:
  WorkspaceStoreInvariantTests and AppModelInvariantTests, random operations,
  printing the failing seed and step.
- **No blocking in the core**: ProcessRunnerTests runs several children per core
  and reads off what each saw running beside it, starved being a thread per core
  at the ceiling.
- **Descriptor exhaustion** lowers the process-wide limit, so
  DescriptorExhaustionTests needs its environment flag and a filter.
- **Git on a timer reads only**: StatusLockTests.
- **A tree still being built wears no badge, and a stage on a listed worktree
  keeps the one it earned**: the badged tests in AppModelGitTests+Refresh and
  the merged-badge one in +Merges, on real git with a gated hook.
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
- **The quit alert answers both keys under any language**: QuitAlertTests, which
  builds it with translated titles, AppKit binding Escape by matching the
  English one.
- **A removal button keeps its red bezel and its Return**:
  DestructiveAlertTests, AppKit taking the key off at every layout and drawing a
  default button in the accent colour. What a presented sheet actually draws is
  not testable here, so the suite holds the properties, not the pixels.
- **Each override binds to its own setting**: SettingsBindingTests, the override
  accessors taking the same arguments and returning the same type.
- **Sidebar counts agree with the columns they summarise**: AgentBoardModelTests
  over every state and both filter positions, the counts being made without
  building a card.
- **An agent mark that draws nothing**: AgentMarkResourceTests parses every mark
  and holds each to its square, a file that will not parse being left out of the
  table rather than crashing a view.
- **An agent typed at a prompt that marks nothing**: the placeholder test in
  ShellLaunchTests holds the generated files to naming the agents, and
  PromptMarkTests runs the real shells and reads what they report.
- **That zsh test caught a word subscript taking characters** for a command run
  by its path, which a syntax check cannot see.
- **A settings page outgrowing its fixed window**: SettingsPageSizeTests lays
  each page out in a window never ordered in and holds it to the window's
  height.
- **Two pages are exempt and say why**: one scrolls on purpose, and one reads
  the machine on appear, so its height is the developer's. Width is not
  checkable at all, a minimum-size measurement reporting where text wraps.
- **A tab strip that stops answering the wheel**: SidewaysWheelTests sends a
  synthesized vertical scroll to the overlay over a real scroller and reads the
  offset back a run loop turn later.
- **Its control is the same event handed straight to the scroller**, which moves
  it by nothing: that is why the catcher exists. It holds both halves, the
  marked scroller being the strip's and the catcher being outside it.
- **A word on screen with no translation, or a translation nothing shows**:
  TranslationTests reads every lookup off the source and checks the keys both
  ways, one per catalogue over its own half.
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
- **The user's git config cannot change what a read means**:
  GitRunnerConfigurationTests reads the isolated keys back and watches an
  all-untracked worktree read dirty.
- **A tag sharing a branch's name decides nothing**: WorktreeMergeTests ties a
  tag to a merged branch, its fixture merging by refname or git takes the tag.
- **Remove leaves a hook the user put in our own group**: AgentHooksTests.
- **A poll reconciles without taking the keyboard, and a cross-column drop takes
  it with the tab**: AppModelGitTests and AppModelTests, both reading the fake
  engine's recorded focus.
- **A comma-decimal locale still sends a report that parses**: HelperTests under
  a real zsh, pointing the user variable at an empty directory or the chain
  reaches the developer's own rc file.
- **The sidebar filter is not folded by the reader's alphabet**:
  SidebarFilterTests reads the source, the current locale being process-wide and
  so not movable for one suite.
- **A tab id written twice keeps the copy whose worktree is still there**:
  WorkspaceRepairTests, the dead one listed first.
- **A notification type no build has heard of is taken to ask**:
  AgentHooksTests.
- **What a failed accept means**: AcceptOutcomeTests, the classification only.
- **Open in Editor leaves the board and refuses a busy worktree, and an escaped
  rename is not undone by the commit after it**: AppModelTests, both against the
  model rather than the field.
- **A worktree path holding a newline is one worktree**: WorktreePathTests
  against real git, the parser's fixtures NUL-separated through a converter so
  they stay readable.
- **A comma-decimal locale gives bash a sane duration**: HelperTests sets the
  clock variable by hand, which the system bash leaves unset.
- **Remove writes nothing to a file holding none of ours, and still takes back a
  half-written install**: AgentHooksTests.
- **A repeat agent report writes nothing observable**: SessionStateModelTests,
  through observation tracking.
- **The worker rules**: BackgroundWorkerTests, with the roster kept by id, an
  older helper's count read as unnamed workers, and a worker's tool calls
  leaving the roster as it was.
- **A held stop leaves a failure alone** whether a worker's prompt covered it or
  it is still standing, so no failure is paid back as a Done:
  BackgroundWorkerTests.
- **A background shell is held for by pid and ended by its exit**:
  BackgroundShellTests, and ProcessAncestryTests finds one among real children
  by its command line.
- **A resuming agent's Done is paid once**, by the woken turn or the deadline,
  never with a worker out: ResumingAgentTests, and SessionStateModelTests
  through the socket with the banner counted.
- **An agent dying with its shell announces nothing in either sweep order**:
  SessionStateModelTests over twelve pairs, a set's order meeting both.
- **Each agent names a worker in its own spelling**, and a start or stop naming
  nobody counts as an unnamed one: AgentHookPayloadTests.
- **A worker that is a conversation of its own is a worker, and its Stop is not
  the pane's Done**: CopilotWorkerTests, captured payloads driven through the
  helper's report into the model.
- **No value in a custom command or editor line is run**, inside the user's
  quotes or out: CustomLineShellTests under five real shells.
- **The plugin follows a child session**: OpenCodePluginRunTests runs the
  generated JavaScript with spawn replaced and reads back what the helper would
  have been called with, a source test passing whatever it was rewritten to.
- **The chip reads the same roster on the row and on the card**, and a Done
  gives way to a worker and comes back once: SessionStateModelTests, through the
  socket, the banner counted.
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
  SessionStateModelTests, using the system shells file so the check is
  independent of which agents the machine has.
- **A status answering after its worktree went badges nothing**:
  AppModelGitTests, real git, the store emptied between the ask and the answer.
- **A focus report that changes nothing writes nothing**: WorkspaceStoreTests,
  through observation tracking, a re-read of a repository's file held to the
  same rule.
- **Only a repository's file lists are held to the checkout**:
  WorktreeFilesTests places a user's home and absolute entries with no failure
  raised.
- **Neither end is a licence to write outside the worktree**: the same suite
  points a user's entry at a parent path, with the worktree nested so the
  mirrored destination is genuinely elsewhere, and finds nothing written.
- **bash keeps its debug trap against one installed at the first prompt**,
  chains to both and hands the last status on: HelperTests, real bash driven
  through a pipe so the prompt command runs between the two.
- **git's own children are looked up on the login PATH**:
  GitRunnerConfigurationTests, through an alias that runs a helper on a PATH of
  the test's own; the same runner without it fails, which is what makes the pass
  mean something.
- **A launched command is given no pipes**, so a shim holding the editor open
  holds no descriptors: ProcessRunnerTests asks the shell whether its own output
  is a pipe.
- **A frame handed another session's surface asks that session for focus**:
  SurfaceFrameTests, in a window never ordered in.
- **A duration no clock could have produced is dropped coming off the channel**:
  SessionStateReportTests and ElapsedTextTests, the trap being a conversion
  outside its range.
- **A branch name git will reject is refused before the pre-create hook**:
  AppModelHookControlTests, the rules themselves held against real git over a
  table in GitRefNameTests, the existing-branch path in WorktreeCreationTests.
- **A bare rebase that replayed nothing is not a landing**: WorktreeMergeTests
  against real git, beside the fast-forward case it mirrors, and
  MergeParserTests for the finish wording old and new.
- **A placeholder inside a value is not expanded again**: AgentFlagsTests.
- **An item promising two files is not delivered on the first**:
  PromisedDropTests.
- **A live socket whose accept backlog is full is not taken for a dead one**:
  UnixSocketServerTests, the queue blocked and the backlog filled by hand.
- **The same suite starts a live server twice** and has a second process try the
  claim, a process's own record locks never conflicting, and holds the path
  limit to the staging name's.
- **The pid the helper reports stops short of the app**: HelperTests with two
  real shell layers under the test process posing as the app;
  ProcessAncestryTests has the walk on its own.
- **The model's half**: SessionStateModelTests, a report naming the app's pid
  tracking none, beside one from a subdirectory marking the deepest worktree
  containing it.
- **Removing the main worktree is refused before the hook and the Trash**:
  AppModelHookControlTests. Without the guard that test bins the fixture.
- **Removing one worktree leaves the record of another whose directory is
  away**, and a Trash that refuses leaves a lock and its reason in place:
  WorktreeForgetScopeTests, against real git.
- **A Trash that takes nothing stops the removal there**, the forget being what
  would unlink a directory still in place: the same suite.
- **A refused create leaves no container directory**: WorktreeCreationTests.
- **A confirmed removal trashes or deletes as its dialog said**, though the
  setting changed while it was up: AppModelGitTests.
- **The Trash is asked off the main thread**: AppModelHookControlTests, the fake
  Trash recording the thread of each call.
- **A worktree path holding a control character still reports from zsh**:
  HelperTests, and every line the socket received must parse. bash is not
  exercised, going through the helper, which encodes.
- **A user-set shell directory variable is followed**: HelperTests, a login
  interactive zsh under a fake home. Only a login shell reads the profile, so
  the login flag is what the test is.
- **Its session and socket variables are blanked**: the runner merges over the
  process's own, and run from a Multishell tab the hooks reported to the
  developer's live app.
- **An empty Enter under a user's prompt command starts no command**:
  PromptMarkTests, real bash with a logging stand-in for the helper, counting
  the started lines.
- **A dead agent with a worker counted no longer holds Working**, and its
  shell's later failure is not an agent waiting on the badge:
  BackgroundWorkerTests in both orders, AgentBoardModelTests with the board
  closed.
- **A hook still running when its worktree is removed in a terminal is ended**:
  AppModelHookControlTests, a sleeping hook, the row removed with real git,
  bounded and with no alert.
- **The ownership rules those rest on**: WorktreeWorkInFlightTests on the plain
  value, a stop handle dropped only by the stage that installed it, a claim
  counted, and only the newest create answering the sheet's Cancel.
- **A failing refresh landing after its project was removed dims nothing**:
  AppModelGitTests, a fake git that waits for a file before failing.
- **A record git will neither remove nor prune after the Trash took the
  directory is its own failure**: WorktreeCoordinatorTests on a fake git,
  RemovalFailureTests for the mapping.
- **A prune that leaves the record listed is still a failure**, and an
  unreadable or empty list counts as listed: the same suite, a fake git whose
  remove fails and whose list still names the path.
- **A greeting holding an equals sign does not cost the login shell its first
  variable**: LoginShellEnvironmentTests, on the parser alone.
- **Numbers in an agent's settings file come back as written**, and a literal
  the grammar refuses or bytes that are not UTF-8 are still refused untouched:
  AgentHooksTests over both sets.
- **A zero or non-finite split weight is refused on decode and on write**:
  DecodingDefaultsTests and WorkspaceStoreTests, whose counter counts store
  operations rather than writes.
- **Foundation-only imports**: checked by hand in a Linux container, Linux being
  out of CI. Views untested, but a value a view reads is.
- **A removal dialog left up for a worktree git no longer lists, and Remove
  offered on the main worktree**: AppModelGitTests and AppModelTests, both
  through the one place each is decided.
- **A second copy of the app writing the workspace file**: AppModelTests hands
  the fake state source an in-use socket and expects the platform asked to hand
  over, no poll started, and no file after a change.
- **Two saves landing out of order**: OrderedSaveTests prepares two, runs the
  later first, and expects the file to hold it.
- **What the git badge counts**: DiffStatParserTests and
  UntrackedLineCounterTests on fixture text and scratch files, the rows that
  carry no line among them, a symlink that is never followed, a file that would
  cross the budget, and the files past the cap.
- **The three together on real git**: WorktreeCoordinatorTests, once per
  indicator setting, plus an untracked directory that is one entry whose lines
  are still counted and a real merge conflict that is no file with no lines.
- **A repository whose own config says not to look at untracked files**:
  GitRunnerConfigurationTests, where the lines are counted anyway.
- **Changing the indicator reads every badge at once**: AppModelGitTests, and a
  read started before the change badges nothing, held open by a fake git until
  the read that replaced it has landed.
- **The status poll asking a missing project or a slow checkout**:
  AppModelGitTests on a fake git, counting the calls, once more for a prompt's
  own refresh of that slow worktree, and once for a read discarded mid-flight,
  which must leave the next read due.
- **The pacing rule itself**: StatusPollPaceTests, and StatusReadLogTests for
  the readings it is applied to, the generation included. Every other model test
  runs unpaced, or a read right after a change would be skipped.
- **A find bar is its pane's own and ends with its pane**: AppModelFindTests
  through the fake engine's recorded searches, over the disabled items, the
  second worktree, the arrows, the keyboard hand-back and the repeat needle.
- **The steps' engine spellings**: FindBindingActionTests, the needle alone and
  the crossed next; their shortcuts being taken from the surface and every
  unbind line accepted by the pinned engine are AppShortcutTests.
- **A watcher tick re-reading every project**: AppModelGitTests adds a second
  repository, adds a worktree to it behind the app's back, and ticks with the
  first project's directory.

## Conventions

- **A new file goes in the folder its subject is in**, one tree mirroring the
  other (layout.md). Harnesses and fakes stay at the suite's root.
- **Git behaviour goes against a real repository**, never mocks. Parsers get
  fixture text, odd lines included.
- **Prefer evidence to a clock.** Concurrency is read off what the children
  recorded about each other, not off how long the batch took. Both were
  wall-clock bounds first, and both flaked.
- **Waiting for a state is the shared helper**, with the assertion after it; a
  fixed sleep fails on a loaded runner and wastes time on a quiet one.
- **Never the developer's machine**: a shell runs against a home the test wrote,
  the model's login environment comes from the harness, and git is the fixture's
  runner rather than the PATH's.
- **A shell given this process's environment takes `Scratch.shellEnvironment`**,
  which empties `HISTFILE`: an exported one had an interactive bash append the
  tests' commands to the developer's own zsh history.
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

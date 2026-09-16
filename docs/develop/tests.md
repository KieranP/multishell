# Tests

What each test catches, and the conventions a new one follows.

## What catches a breach of the rules

`docs/design/` says why these are the rules.

- Persisted defaults, unknown enum values included: DecodingDefaultsTests.
- Old state file still loads with what it said: TabGroupMigrationTests reads a
  real pre-columns file through `WorkspaceStore.restored`;
  NotificationPreferenceMigrationTests reads the notification picker this
  build replaced with toggles.
- WorkspaceInvariants and `repairReferences`: WorkspaceStoreInvariantTests,
  AppModelInvariantTests, random operations, printing failing seed and step.
- No blocking in the core: ProcessRunnerTests runs 96 children under a
  wall-clock bound. DescriptorExhaustionTests lowers the process-wide limit,
  so it needs `MULTISHELL_EXHAUST_DESCRIPTORS=1` and a `--filter`.
- Git on a timer reads only: StatusLockTests.
- A tree still being built wears no badge, and a stage on a listed worktree
  keeps the one it earned: the `Badged` tests in AppModelGitTests+Refresh and
  `aWorktreeStillBeingBuiltDoesNotWearTheMergedBadge` in +Merges, on real
  git with a gated hook where the window matters.
- Git against real repositories, bare clone with worktrees beside it included:
  RepositoryFixture. FakeGit only for what real git cannot do on demand.
  Parsers get fixture text, CRLF and malformed lines included.
- Detection runs against fake executables on a fake PATH, never the machine.
  Hooks run through real shells under a substitute home.
- A shortcut's two spellings agree, clipboard ones stay with the terminal:
  AppShortcutTests, pinned against the config Ghostty was given before it was
  derived.
- Identifiers spelled in both Swift and the generated `Info.plist` still
  match: BundleDeclarationTests, reading `make-app.sh` out of the checkout.
  Nothing at build or run time notices these having parted.
- Each override binds to its own setting: SettingsBindingTests, since
  `hasOverride` and `overrideValue` take the same arguments and return the
  same type.
- Sidebar Agents counts agree with the columns they summarise:
  AgentBoardModelTests, every state and both filter positions.
  `agentLaneCounts` counts without building a card, so a shell reporting a new
  prompt does not re-render the sidebar, and the two ways of counting can part.
- A settings page outgrowing its fixed window: SettingsPageSizeTests lays the
  pages of both settings windows out at 560 in an NSHostingView in an NSWindow
  never ordered in, and holds each to 600. No screen and no permission: what
  macOS gates is reading another process, not your own, and CI's runner has
  the window server this needs. Two pages are exempt and say why: Hooks
  scrolls on purpose, and Agent settings reads the machine on appear, so its
  height is the developer's rather than anyone's. Width is not checkable at
  all, a minimum-size measurement reporting where text stops wrapping rather
  than where a control is cut off.
- A tab strip that stops answering the mouse wheel: SidewaysWheelTests sends
  a synthesized vertical scroll to the overlay over a real scroller and reads
  the offset back a run loop turn later, since a scroller answers on its own
  schedule. The control is the same event handed straight to the scroller,
  which moves it by nothing: that is why the catcher exists. One test needs
  the window server SettingsPageSizeTests does, and holds both halves of the
  regression: a sidebar that scrolls laid out beside a strip that does, the
  marked scroller having to be the strip's rather than the sidebar's, and the
  catcher having to be outside the scroller, since a scroller never calls a
  catcher inside its own content.
- A word on screen with no translation, or a translation nothing shows:
  TranslationTests reads every `t("…")` off the source, from its own
  `#filePath`, and checks the keys against `Localizable.strings` and
  `Localizable.stringsdict` both ways. One per catalogue, each over its own
  half: `Tests/MultishellCoreTests` over `Sources`, `Apps/macOS/Tests` over
  that app's. The app's also pins the shadowing the split rests on, that a
  view's `t(_:_:)` is the app's own and answers from the app's catalogue, and
  that the words written in both catalogues read the same in both, which is
  the app's to check because the libraries do not know a frontend exists.
  Each counts a call's arguments against the placeholders in its phrase, as
  the compiler would have had the keys been an enum, fails a phrase taking
  several arguments that does not number them, and refuses a `%s`, which
  takes a C string and would be a crash rather than a wrong word. Every
  counted form is rendered at one and at many, since a stringsdict whose
  format key does not name its own sub-dictionary answers with the raw format
  and only two of the ten were exercised by what they say. It expects over a
  hundred call sites, so a scan that has lost the source tree fails rather
  than passes, and it reads the file as text as well as parsed, to catch an
  entry written twice, which loads as one without a word, and one left blank,
  which every other check passes and shows nothing. The keys come off the
  source and the words out of the built bundle, which can be a copy made
  before the edit: one check compares the two files byte for byte, so `swift
  test --skip-build` after changing the catalogue says so instead of passing
  on what is no longer there.
- State that will not open, not just will not decode, is moved aside, and a
  file that cannot be moved either is never saved over: PersistenceTests, one
  unreadable file and one in a directory that takes no rename.
- The user's git config cannot change what a read means, and a tag sharing a
  branch's name decides nothing: GitRunnerConfigurationTests reads the two
  isolated keys back through `git config --get` and watches an all-untracked
  worktree read dirty; WorktreeMergeTests ties a tag to a merged branch. That
  fixture merges by refname, or git takes the tag and nothing lands.
- Remove leaves a hook the user put in our own group: AgentHooksTests.
- A poll reconciles without taking the keyboard, and a cross-column drop takes
  it with the tab: AppModelGitTests removes a worktree behind the app's back,
  AppModelTests drops a tab on another column's tab. Both read `FakeEngine`'s
  recorded focus.
- A comma-decimal locale still sends a report that parses: HelperTests, real
  zsh under `de_DE.UTF-8`. It points `MULTISHELL_USER_ZDOTDIR` at an empty
  directory, or the chain reaches the developer's own `.zshrc`, whose locale
  decides the test instead; it skips where the locale is absent rather than
  failing on its absence.
- The sidebar filter is not folded by the reader's alphabet:
  SidebarFilterTests reads the source, `Locale.current` being process-wide and
  so not movable for one suite while the others run beside it.
- A tab id written twice keeps the copy whose worktree is still there:
  WorkspaceRepairTests, the dead one listed first.
- A notification type no build has heard of is taken to ask: AgentHooksTests.
- What a failed `accept` means: AcceptOutcomeTests, the classification only.
  A real descriptor shortage is DescriptorExhaustionTests' territory and the
  spin it used to cause is not staged.
- Open in Editor leaves the board and refuses a busy worktree, and an Escaped
  tab rename is not undone by the commit that follows it: AppModelTests, both
  against the model rather than the field, which is why the editing tab moved
  out of the strip's own state.
- A worktree path holding a newline is one worktree: WorktreePathTests
  against real git, and the parser's own fixtures are NUL-separated through a
  converter so they stay readable.
- A comma-decimal locale gives bash a sane duration: HelperTests sets
  `EPOCHREALTIME` by hand, which Apple's bash 3.2 leaves unset.
- Remove writes nothing to a file holding none of ours, and still takes back a
  half-written install: AgentHooksTests.
- A repeat agent report writes nothing observable: SessionStateModelTests,
  through `withObservationTracking`.
- A counting tick leaves a Waiting, a Done or a Failed alone:
  SessionStatesTests, both directions, and the owed Done still paid at the
  last worker out.
- Export keeps a hook the user refused and does not trust it into the
  bargain: AppModelHookControlTests, against the real file on disk. The same
  suite exports over a file holding a `$schema` line, and
  SharedProjectSettingsTests holds the whole rule: an unknown key, a nested
  one, an order no build names and a wrong-typed flag all come back as they
  were, and what `write` returns equals a fresh load.
- A stage ending while the Agents board is up leaves it up, and the first
  tab opens and starts under the create settings wherever the user is
  looking, agent included, without moving the selection or the keyboard:
  AppModelHookControlTests, the hook cancelled under the board and with
  another worktree selected, opening on select turned off so only the create
  pair can explain the tab, and the fake engine's opens and focus read back.
- The login environment is not known before its PATH has been scanned:
  SessionStateModelTests polls for the environment and reads the detections
  in the same turn, `/etc/shells` being what makes the check independent of
  which agents the machine has.
- A `git status` answering after its worktree went badges nothing:
  AppModelGitTests, real git, the store emptied between the ask and the
  answer, one yield being what puts the refresh at its await.
- A focus report that changes nothing writes nothing to the workspace:
  WorkspaceStoreTests, through `withObservationTracking`, the same session
  focused twice and its tab activated again.
- bash keeps its DEBUG trap against one installed at the first prompt, chains
  to that one and to the `.bashrc` one, and hands `$?` on: HelperTests, real
  bash driven through a pipe so `PROMPT_COMMAND` runs between the two, a
  `bash -c` script never prompting. What says the chain really runs is a
  firing after the trap came back, not the one at the prompt it arrived at,
  and a body naming a path it cannot reach: run as one word, bash says so
  once per command.
- git's own children are looked up on the login PATH:
  GitRunnerConfigurationTests, through an alias that runs a helper on a PATH
  of the test's own; the same runner without it fails, which is what makes
  the pass mean something.
- A launched command is given no pipes, so a shim that holds the editor open
  holds no descriptors: ProcessRunnerTests asks the shell whether its own
  stdout is a pipe, counting them in a process this busy being hopeless.
- A frame handed another session's surface asks that session for focus:
  SurfaceFrameTests, in a window never ordered in.
- A duration no clock could have produced is dropped coming off the channel
  and renders as nothing: SessionStateReportTests and ElapsedTextTests, the
  trap being `Int(_: Double)` outside its range.
- A branch name git will reject is refused before the pre-create hook:
  AppModelHookControlTests; the rules themselves are held against real
  `git check-ref-format` over a table in GitRefNameTests. The existing-branch
  path is held to it as well: WorktreeCreationTests, an empty, blank, spaced
  and `HEAD` name each against a hook that leaves a marker.
- A bare `git rebase` that replayed nothing is not a landing:
  WorktreeMergeTests against real git, beside the fast-forward case it
  mirrors, and MergeParserTests for the finish wording old and new.
- A placeholder inside a value is not expanded again: AgentFlagsTests.
- An item promising two files is not delivered on the first: PromisedDropTests.
- A live socket whose accept backlog is full is not taken for a dead one:
  UnixSocketServerTests, the server's queue blocked and the backlog filled by
  hand. The same suite starts a live server twice and has a second process
  try the claim, a process's own record locks never conflicting with each
  other, and holds the path limit to the staging name's, 102 and 103 bytes
  refused under the socket's own name where 101 binds.
- The pid the helper reports stops short of the app: HelperTests, two real
  `sh -c` layers under the test process posing as the app, the report naming
  the outer shell; ProcessAncestryTests has the walk on its own. The model's
  half, a report naming the app's pid tracking none, is SessionStateModelTests,
  beside a report from a subdirectory marking the deepest worktree containing
  it, the harness nesting one worktree inside the other.
- Removing the main worktree is refused before the hook and the Trash:
  AppModelHookControlTests. Without the guard that test bins the fixture.
- Removing one worktree leaves the record of another whose directory is away,
  and a Trash that refuses leaves a lock and its reason in place:
  WorktreeForgetScopeTests, against real git. The same suite hands the
  coordinator a Trash that takes nothing and expects the removal to stop
  there, the forget being a `remove --force --force` that would unlink a
  directory still in place.
- A refused create leaves no container directory: WorktreeCreationTests, the
  branch name taken and the worktree directory three levels deep.
- The Trash is asked off the main thread: AppModelHookControlTests, the fake
  Trash recording the thread of each call.
- A worktree path holding a control character still reports from zsh:
  HelperTests, real zsh with a tab, a newline, a quote and a backslash in the
  path, and every line the socket received must parse. bash is not exercised,
  going through the helper, which encodes.
- A `ZDOTDIR` the user's `.zprofile` sets is followed: HelperTests, a login
  interactive zsh under a fake home, beside the `.zshenv` case it was modelled
  on. Only a login shell reads the profile, so the `-l` is what the test is.
- Foundation-only imports: checked by hand in a `swift:6.0` container, Linux
  being out of CI. Views untested, but a value a view reads is.
- A removal dialog left up for a worktree git no longer lists, and Remove
  offered on the main worktree: AppModelGitTests removes the worktree behind
  the app's back and refreshes; AppModelTests asks to remove the primary and
  expects no dialog and no operation. Both go through `forgetWorktrees` and
  `Worktree.isRemovable`, the one place each is decided.
- A second copy of the app writing the workspace file: AppModelTests hands the
  fake state source an in-use socket and expects the platform asked to hand
  over, no poll started, and no file after a change, the debounce and
  `saveNow` both.
- Two saves landing out of order: OrderedSaveTests prepares two, runs the
  later first, and expects the file to hold it.
- The status poll asking a missing project or a slow checkout: AppModelGitTests
  on a fake git, once with the project marked missing and once with a `status`
  that sleeps past the pace's floor, counting the calls; StatusPollPaceTests
  holds the rule itself. Every other model test runs `.unpaced`, or a read
  right after a change would be skipped.
- A watcher tick re-reading every project: AppModelGitTests adds a second
  repository, adds a worktree to it behind the app's back, and ticks with the
  first project's directory; the second must stay unread and nothing re-armed
  until a tick names no directory.

## Conventions

- Git behaviour goes against a real repository with RepositoryFixture, never
  mocks. Parsers get fixture text, odd lines included.
- Prefer evidence to a clock. Concurrency is read off what the children
  recorded about each other, not off how long the batch took; a call that
  returned before a hook finished is read off the state it returned in. Both
  were wall-clock bounds first, and both flaked.
- A bound that is left tells one outcome from another, not a fast machine
  from a slow one: the child sleeps thirty seconds and the bound is twelve, so
  what fails it is the stop never arriving. Do not size a bound to a measured
  figure plus headroom; the runner's mood decides that. `make test` holds a
  lock across worktrees for the same reason; a bare `swift test` does not, so
  two of those at once is the one way left to fail a bound on a fast machine.
- A test that reads something process-wide, the open descriptor count being
  the one so far, is reading the other suites too: they run beside it in the
  same process. Take the lowest of several seconds of samples rather than one
  reading, and expect to revisit it when a test that spawns in bulk arrives.
- Real git comes from a fixture, whose runner carries `commit.gpgsign=false`:
  a developer whose global config signs would be asked for the key once per
  fixture commit. It rides on the runner, so a clone a new test adds needs no
  step of its own.

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
- Closed tab's shell ends and is collected: SwiftTermHostTests, real shells.
  Ghostty's path uncovered: its surface needs a window and Metal.
- Git on a timer reads only: StatusLockTests.
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
  the window server this needs. Two pages are left out and say why: Hooks
  scrolls on purpose, and Agent settings reads the machine on appear, so its
  height is the developer's rather than anyone's. Width is not checkable at
  all, a minimum-size measurement reporting where text stops wrapping rather
  than where a control is cut off.
- A word on screen with no translation, or a translation nothing shows:
  TranslationTests reads every `t("…")` off the source, from its own
  `#filePath`, and checks the keys against `Localizable.strings` and
  `Localizable.stringsdict` both ways. One per catalogue, each over its own
  half: `Tests/MultishellCoreTests` over `Sources`, `Apps/macOS/Tests` over
  that app's. The app's also pins the shadowing the split rests on, that a
  view's `t(_:_:)` is the app's own and answers from the app's catalogue,
  and that the handful of words written in both catalogues still read the
  same in both, which is the app's to check because the libraries do not
  know a frontend exists. It also counts each call's arguments
  against the placeholders in its phrase, which is what the compiler would
  have done had the keys been an enum, fails a phrase taking several
  arguments that does not number them, and refuses a `%s`, which takes a C
  string and would be a crash rather than a wrong word. Every counted form
  is rendered at one and at many, since a stringsdict whose format key does
  not name its own sub-dictionary answers with the raw format and only two
  of the ten were exercised by what they say. It expects to find over a hundred
  call sites, so a scan that has lost the source tree fails rather than
  passes, and it reads the file as text as well as parsed, to catch an
  entry written twice, which loads as one without a word, and one left
  blank, which every other check here passes and shows nothing. The keys come off the source and the words out of the built
  bundle, which can be a copy made before the edit: one check compares the
  two files byte for byte, so `swift test --skip-build` after changing the
  catalogue says so instead of passing on what is no longer there.
- State that will not open, not just will not decode, is moved aside, and a
  file that cannot be moved either is never saved over: PersistenceTests, one
  unreadable file and one in a directory that takes no rename.
- The user's git config cannot change what a read means, and a tag sharing a
  branch's name decides nothing: GitRunnerTests reads the two isolated keys
  back through `git config --get` and watches an all-untracked worktree read
  dirty; WorktreeMergeTests ties a tag to a merged branch. That fixture merges
  by refname, or git takes the tag and nothing lands.
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
- Foundation-only imports: checked by hand in a `swift:6.0` container, Linux
  being out of CI. Views untested, but a value a view reads is.

## Conventions

- Git behaviour goes against a real repository with RepositoryFixture, never
  mocks. Parsers get fixture text, odd lines included.
- Prefer evidence to a clock. Concurrency is read off what the children
  recorded about each other, not off how long the batch took; a call that
  returned before a hook finished is read off the state it returned in. Both
  were wall-clock bounds first, and both flaked.
- A bound that is left tells one outcome from another, not a fast machine
  from a slow one: the child sleeps thirty seconds and the bound is ten, so
  what fails it is the stop never arriving. Sizing a bound to a measured
  figure plus headroom is what to avoid; it is the runner's mood that decides
  it. `make test` holds a lock across worktrees for the same reason; a bare
  `swift test` does not, so two of those at once is the one way left to fail
  a bound on a fast machine.
- A test that reads something process-wide, the open descriptor count being
  the one so far, is reading the other suites too: they run beside it in the
  same process. Take the lowest of several seconds of samples rather than one
  reading, and expect to revisit it when a test that spawns in bulk arrives.
- Real git comes from a fixture, whose runner carries `commit.gpgsign=false`:
  a developer whose global config signs would be asked for the key once per
  fixture commit. It rides on the runner, so a clone a new test adds needs no
  step of its own.

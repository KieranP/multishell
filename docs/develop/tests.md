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

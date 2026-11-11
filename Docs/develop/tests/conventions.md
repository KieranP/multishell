# Conventions

The conventions a new test follows. Why each rule holds is in `design/`.

## Conventions

- **A new file goes in the folder its subject is in** (layout.md), and a value's
  `<Type>+Sample.swift` builder stays at the suite's root with the harnesses. A
  service's fixtures, `GitHubFixtures` and `CircleCIFixtures`, sit with that
  service's tests instead, each used by those alone.
- **Git behaviour goes against a real repository**, never mocks:
  RepositoryFixture, a bare clone with worktrees beside it included. FakeGit
  only for what real git cannot do on demand. Parsers get fixture text, odd
  lines included.
- **Real git comes from a fixture whose runner turns commit signing off**, or a
  developer whose global config signs would be asked for the key once per
  fixture commit. It rides on the runner, so a clone needs no step of its own.
- **A fixture's `WorktreeGit` skips the wait before a new index is written**,
  `settlesNewIndex: false`, or each of the suites' hundreds of creates waits a
  second. The four tests about that wait keep it on, one each in
  WorktreeCoordinatorCreationTests and WorktreeCoordinatorStoppedAddTests, two
  in WorktreeGitCreationTests.
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
- **No test calls `Process.waitUntilExit()` after an await.** On a thread other
  than the one that ran the process, as a resumed task often is, about one wait
  in eighty never returned here, the child long reaped; `.timeLimit` cannot end
  a blocked call either. `WaitingShell` waits on its termination handler, which
  returned all 1,200 times; a launch and wait in one synchronous function is
  safe, 1,200 of 1,200.
- **No test thread waits on work sent to `DispatchQueue.global()`.** That queue
  adds no thread while default-QoS threads fill the cores, so three
  `SaveOrderTests` froze every CI run on a three-core runner. `HeldWrite` runs
  on a `Thread` of its own; production code reaches Dispatch through
  `runOnDispatch`, whose utility queue is another pool.
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
  only there (build/building-locally.md), so a test names every file it writes.
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
- **The test process ignores SIGPIPE**, set by `Detached.output`: input written
  to a shell that had already exited killed the whole run about one time in
  three under the shell suites' load.
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

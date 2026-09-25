# Building, running, verifying

## Requirements

- **Xcode, at the floor COMPAT.md names**, with Swift 6.2, the manifest's tools
  version. The app build runs `xcodebuild`, which the command line tools alone
  do not have.
- **git on PATH**, and **prettier** for the Markdown half of `make format`. CI
  does not run prettier; a Claude Code hook runs it on every `.md` an agent
  writes, and skips it quietly where prettier is missing.

## Build, test, run

- **The Makefile is the entry point**: `signing-identity` once per machine, then
  `test`, `test-app`, `build`, `release`, `run`, `install`, `format` and `lint`.
  Each carries a comment line above it in the Makefile saying what it does.
- **`make-app.sh` builds the app binary with `xcodebuild`**, wraps it in a
  bundle, copies the resource bundles in (the engine's terminfo must be there),
  builds the CLI the same way into the bundle's helpers, writes the Info.plist
  and signs both.
- **Signed with the hardened runtime and the entitlements** in `Resources/`
  (design/signing.md).
- **The short version is three integers**, the only form Apple's key takes: a
  `vX.Y.Z` tag on HEAD, else the commit's date. An rc tag on the same commit is
  passed over, where `git describe` picked it when annotated. The build number
  is the commit count, and `MultishellCommit` names the commit, with a suffix
  for a modified tree. The About panel shows it beside the build number, so a
  bug report still says what was installed: AboutPanelTests.
- **The first build downloads the libghostty xcframework**, which is large; a
  test build needs it too, the app being in the same package.
- **`build-lib.sh` holds the functions `make-app.sh` sources**, not runs: the
  copyright holder, the version, the commit, the build number, the worktree
  variant, the xcodebuild call, the checks and the signing. What stays in
  `make-app.sh` is the paths and the order of the steps.
- **The Info.plist is a template filled in by placeholder**, and
  InfoPlistTemplateTests reads it out of the checkout (tests.md). Substitution
  is bash's own, so a value may hold a newline or an ampersand unescaped. The
  replacement is quoted because bash 5.2 and later read an unquoted `&` as the
  placeholder, and the assignment is not, because 3.2 then keeps the quotes.
- **macOS needs a bundle** for a Dock icon, activation and the menu bar, and
  SwiftPM emits a bare executable.
- **A worktree's name is spelled down to safe characters** before it reaches the
  Info.plist: an unescaped ampersand in a branch name makes the file
  unparseable, and a bundle whose Info.plist will not parse does not launch.
- **The language list is built from the app half's folders alone**, which is
  what makes a language pickable in System Settings. The libraries' half has to
  keep pace, or the app draws its windows translated and says the model's words
  in English.
- **`make signing-identity` creates the self-signed certificate**; without it
  the build signs ad hoc and says so. Not for distribution: it is so the user's
  permission grants survive a rebuild.
- **Every target works the same from a git worktree**, and two can build at
  once: the scratch directories are per-worktree and the shared caches lock only
  briefly.
- **Running the tests is the exception**, several bounds being wall-clock. So
  `make test` compiles unguarded, then runs under a lock file: a second worktree
  compiles alongside the first and waits, silently, only for its turn to run.
- **`lockf -k` keeps the lock file**, which is what gives the queue its order.
  Where there is no `lockf`, the suites run unguarded.
- **A bare `swift test` takes no lock**, and nothing caps the compiler's own
  parallelism, so several full builds at once still oversubscribe the machine.
- **`make test` runs the suites in a write sandbox**, `Scripts/test-sandbox.sb`
  through `sandbox-exec`: the build tree, SwiftPM's caches and the temporary
  directories only. A bare `swift test` has none, so run the tests through make.
  Where there is no `sandbox-exec`, `make test` runs the suites unconfined.
- **SwiftPM sandboxes its manifest compile**, and one sandbox cannot be applied
  inside another, so the sandboxed run passes `--disable-sandbox`, which lifts
  only SwiftPM's.
- **A debug bundle built in a worktree names it** in its state file and socket
  (state-on-disk.md), so two can run at once.

## Why the app is built through xcodebuild

- **`swift build` wrote the tree's own build path into the binary** as the place
  the resource accessor looks after the app root, and codesign refuses anything
  at the app root.
- **So an installed app read the engine's terminfo from the build directory**,
  and the next build there took it away: every shell started with a TERM it had
  no entry for, drew doubled letters and lost key combinations.
- **Xcode's own build of the same package writes no path** and looks in the
  bundle's resources first, so the script runs `xcodebuild` and refuses a binary
  that carries a build path.
- **The CLI comes the same way**, reading the libraries' catalogue on every
  hook, so it would fail the same way. Both go through the same checks.
- **The checks pipe into a counting grep, not a quiet one**: under `pipefail` a
  quiet grep quits at its first match, `strings` writes into a closed pipe, and
  the pipeline's SIGPIPE status reads a match as a miss.
- **The package scheme signs, ad hoc**, which the script does itself afterwards
  with the certificate, hence code signing off in the xcodebuild call.
- **And it compiles every configuration with profiling on**, so the binary ran
  instrumented and tried to write a profile at exit. Coverage mapping off is the
  setting that stops it, and the script checks the sections are gone rather than
  trusting it.
- **No destination names plain macOS alone**: libghostty declares Mac Catalyst,
  so the platform matches both, the variant form is refused, and a package build
  without a destination is refused. The script checks the binary's build version
  says macOS rather than trusting the order.
- **`-quiet` prints a failure for a compile that only warned**, so each run is
  logged, shown whole on failure and reduced to its warning and error lines on
  success.
- **Cost**: xcodebuild keeps a derived directory of its own, so everything
  compiles twice for anyone running the tests and the build. The app's and the
  helper's schemes share it.
- **CI runs two jobs in parallel**: build and test, and the lint. It calls
  `swift test` directly, so it takes no lock and has no write sandbox: a test
  writing outside the temporary directories passes there. It shares only the
  one-test-per-core cap with `make test`, and a run past 30 minutes is stopped.
  It builds without debug info, which took a cold build from 38 s to 29 s here,
  so a crash backtrace from CI has no line numbers.

## Before you say something works

- **Format what you touched, then lint, test, build and release.** All pass, no
  warnings.

## What you cannot verify

- **You cannot see or drive the app.** No Apple events, no screen recording. Do
  not try, and do not ask for those permissions.
- **You can lay a view out in-process.** A hosting view inside a window that is
  never ordered in measures and renders, asking for nothing, and the sizing
  options give the size SwiftUI would refuse to go below. AppSettingsWindowTests
  is the pattern.
- **It still needs a window server**, which is a session rather than a
  permission; CI's runner has one.
- **A tab band is drawn outside the AppKit hierarchy**: in no bitmap and in no
  measured size, so a band that clips stays invisible here.
- **The image renderer refuses a tab view outright** and draws a placeholder,
  where the AppKit display path renders the tab's content.
- **A minimum width reports where text stops wrapping**, not where a control is
  cut off, so it reads as a clip for any page with a caption.
- **Metal is untried**: a terminal surface is expected to come out blank,
  neither path capturing a drawable, but nobody has looked.
- **Otherwise a view change stops at the checks above**: say what is unverified,
  leave the looking to the user, and record it in BUGS.md with the fallback.
- **Anything decidable without a screen belongs in a plain value** in
  MultishellAppCore, tested there.

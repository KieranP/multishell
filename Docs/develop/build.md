# Building, running, verifying

## Requirements

- **Xcode, at the floor COMPAT.md names**, with Swift 6.2, the manifest's tools
  version. The app build runs `xcodebuild`, which the command line tools alone
  do not have.
- **git on PATH**, and **prettier** for the Markdown half of `make format`. CI
  does not run prettier; a Claude Code hook runs it on every `.md` an agent
  writes, and skips it quietly where prettier is missing.
- **Zig, at the version `ThirdParty/ghostty/build.zig.zon` names**, and Xcode's
  Metal toolchain (`xcodebuild -downloadComponent MetalToolchain`), for
  libghostty. Ghostty's own renderer shaders need the Metal compiler, which
  custom shaders being off does not remove. The build script fetches the
  submodule and keeps it at the pin, so a plain clone needs nothing more.
- **The script takes `$ZIG` when set, refusing it at another version, else the
  first matching Zig of `zig` on PATH and Homebrew's `zig@X.Y`.** Homebrew's
  plain `zig` moves to a new release before Ghostty does, and its versioned
  formula is keg-only, so never on PATH.

## Build, test, run

- **The Makefile is the entry point**: `signing-identity` once per machine, then
  `test`, `compile-app`, `build`, `release`, `run`, `install`, `format` and
  `lint`.
- **macOS needs a bundle** for a Dock icon, activation and the menu bar, and
  SwiftPM emits a bare executable, so `make-app.sh` builds the app and the CLI
  with `xcodebuild` and wraps them in one, the CLI among its helpers.
- **libghostty finds its terminfo through `GHOSTTY_RESOURCES_DIR`**, which the
  app sets to `Contents/Resources/ghostty` at launch: a release libghostty reads
  the variable before its own walk up from the executable, so one inherited from
  a Ghostty tab would win. TERMINFO points at `terminfo` beside it. Without it
  every shell starts with a TERM it has no entry for, so the bundling script
  refuses to finish without it.
- **Signed with the hardened runtime and the entitlements** in `Resources/`
  (design/signing.md).
- **The short version is three integers**, the only form Apple's key takes: a
  `vX.Y.Z` tag on HEAD, else the commit's date. An rc tag on the same commit is
  passed over, where `git describe` picked it when annotated. The build number
  is the commit count, and `MultishellCommit` names the commit, with a suffix
  for a modified tree. The About panel shows it beside the build number, so a
  bug report still says what was installed: AboutPanelTests.
- **Every target that compiles builds libghostty first**, from the submodule,
  into `.build/ghostty`: about 80 s cold here, nothing while the submodule, the
  patches, the script, Zig and Xcode are unchanged, and 2 s after a `make clean`
  or `swift package reset`: Zig keeps its cache and fetched packages in the
  submodule's `.zig-cache/` and `zig-pkg/`, which neither touches. A bare
  `swift build` needs it built already, the package naming the xcframework by
  path; `make libghostty` does it.
- **`make-app.sh` keeps only the paths and the order of the steps**; its
  functions are in `build-lib.sh`, which it sources (and `build-ghostty.sh` its
  `die`).
- **The Info.plist is a template filled in by placeholder**, and
  InfoPlistTemplateTests reads it out of the checkout (tests.md). Substitution
  is bash's own, so a value may hold a newline or an ampersand unescaped. The
  replacement is quoted because bash 5.2 and later read an unquoted `&` as the
  placeholder, and the assignment is not, because 3.2 then keeps the quotes.
- **A worktree's name is spelled down to safe characters** before it reaches the
  Info.plist: an unescaped ampersand in a branch name makes the file
  unparseable, and a bundle whose Info.plist will not parse does not launch.
- **The language list is built from the app half's folders alone**, which is
  what makes a language pickable in System Settings. The libraries' half has to
  keep pace, or the app draws its windows translated and says the model's words
  in English.
- **`make signing-identity` creates the self-signed certificate** that keeps
  permission grants across rebuilds; it is not for distribution
  (design/signing.md). `MULTISHELL_SIGN_IDENTITY` picks another certificate, and
  `-` forces ad hoc.
- **Every target works the same from a git worktree**, and two can build at
  once: the scratch directories are per-worktree and the shared caches lock only
  briefly. Each worktree has its own clone of the submodule, so a new one's
  first libghostty build starts with no `.zig-cache/` or `zig-pkg/`. A debug
  bundle built in one names it in its state file and socket, so two can run at
  once (state-on-disk.md).
- **Running the tests is the exception**, several bounds being wall-clock.
  `make test` compiles unguarded, then runs under a lock file: a second worktree
  compiles alongside the first and waits silently for its turn to run.
- **`lockf -k` keeps the lock file**, which is what gives the queue its order.
  Where there is no `lockf`, the suites run unguarded.
- **A bare `swift test` takes no lock**, and nothing caps the compiler's own
  parallelism, so several full builds at once still oversubscribe the machine.
- **`make test` runs the suites in a write sandbox**, `Scripts/test-sandbox.sb`
  through `sandbox-exec`: the build tree, SwiftPM's caches and the temporary
  directories only. A bare `swift test` has none, so run the tests through make.
  Without `sandbox-exec`, `make test` runs the suites unconfined.
- **SwiftPM sandboxes its manifest compile**, and one sandbox cannot be applied
  inside another, so the sandboxed run passes `--disable-sandbox`, which lifts
  only SwiftPM's.

## Why the app is built through xcodebuild

- **`swift build` wrote the tree's own build path into the binary** as the place
  the resource accessor looks after the app root, and codesign refuses anything
  at the app root.
- **So an installed app read its resources, terminfo among them, from the build
  directory**, and the next build there took them away: every shell started with
  a TERM it had no entry for, drew doubled letters and lost key combinations.
- **Xcode's own build of the same package writes no path** and looks in the
  bundle's resources first, so the script runs `xcodebuild` and refuses a binary
  that carries a build path.
- **The CLI is built the same way and checked the same**, linking the same
  libraries and so able to carry the same path.
- **The checks pipe into a counting grep, not a quiet one**: under `pipefail` a
  quiet grep quits at its first match, `strings` writes into a closed pipe, and
  the pipeline's SIGPIPE status reads a match as a miss.
- **The package scheme signs, ad hoc**, which the script does itself afterwards
  with the certificate, hence code signing off in the xcodebuild call.
- **And it compiles every configuration with profiling on**, so the binary ran
  instrumented and tried to write a profile at exit. Coverage mapping off is the
  setting that stops it, and the script checks the sections are gone rather than
  trusting it.
- **No destination names plain macOS alone**: SwiftPM offers every package for
  Mac Catalyst too, so the platform matches both, the variant form is refused,
  and a package build without a destination is refused. The script checks the
  binary's build version says macOS rather than trusting the order.
- **`-quiet` prints a failure for a compile that only warned**, so each run is
  logged, shown whole on failure and reduced to its warning and error lines on
  success.
- **Cost**: xcodebuild keeps a derived directory of its own, shared by the app's
  and the helper's schemes, so everything compiles twice for anyone running the
  tests and the build.
- **CI runs two jobs in parallel**: build and test, and the lint. It calls
  `swift test` directly, so it takes no lock and has no write sandbox: a test
  writing outside the temporary directories passes there. It shares only the
  one-test-per-core cap with `make test`, and a run past 60 minutes is stopped.
  libghostty's cache is saved as soon as it is built, so a red run still keeps
  it; a cold build's time on CI is unmeasured. It builds the package without
  debug info, which took a cold build from 38 s to 29 s here, so a crash
  backtrace from CI has no line numbers.
- **A CI step that writes a script's output to `$GITHUB_OUTPUT` assigns it to a
  variable first.** A failing script inside `echo`'s `$(...)` leaves the step
  green, which once gave the build an empty Zig version and cache key.

## How strict the compiler and the lints are

- **Every target imports each module it uses** (`MemberImportVisibility`).
  Without it a file could use another module's extension members while any file
  in its target imported that module, so a clean build proved no import dead:
  three imports removed on that evidence were needed, and 56 files used a module
  they never imported.
- **`any` is written on every existential** (`ExistentialAny`), and **a warning
  fails the build**.
- **StrictMemorySafety is off**: 427 sites, nearly all libghostty's C API and
  Darwin's, each wanting an `unsafe` that says nothing a reader can act on.
  `InternalImportsByDefault` and `ImmutableWeakCaptures` found nothing here, so
  they are left for Swift 7 to turn on.
- **swift-format rules still off**, listed here because `.swift-format` is JSON
  and takes no comments: `NoLeadingUnderscores` (a persisted `_0` coding key),
  `UseWhereClausesInForLoops` (a `guard … continue` reads as the rest do),
  `NeverForceUnwrap` and `NeverUseForceTry` (SwiftLint's own rules cover
  Sources), `AllPublicDeclarationsHaveDocumentation` (615 undocumented), and
  `BeginDocumentationCommentWithOneLineSummary`, 878 doc comments written as
  prose.
- **Every SwiftLint rule runs but those in `disabled_rules`**, each with its
  reason in `.swiftlint.yml`. Layout rules run beside swift-format where the two
  agree; where they disagree, as on brace placement after a full header, import
  order and a lone wrapped element's trailing comma, swift-format's answer
  stands. They cost about 0.3 s of SwiftLint's 1.1 s uncached; swift-format
  takes 4 s.
- **SwiftLint is pinned by `swiftlint_version`**, and any other version refuses
  to run. With every rule on, a newer SwiftLint would switch its new rules on
  unasked, so a bump is when they are reviewed. CI downloads that release;
  locally, Homebrew's must match.
- **Sources take no force unwrap, `try!` or `as!`**; the one left is marked
  where it stands. `Tests/.swiftlint.yml` lets a test stop on a broken fixture,
  lets a suite run as long as its cases, and keeps `#expect(x == [])` over
  `isEmpty`, since it prints `x` when it fails.
- **Size and complexity limits sit just above the largest that exists**: 60-line
  functions, complexity 15, 9 parameters, 4-member tuples, types nested two
  deep, 120-column lines. They stop growth rather than force a split. Four
  exceed them by choice and are marked: `SVGPathParser.path(fromData:)` (kept
  whole on 2026-09-30), `OpenCodePlugin.javaScript(helperExpression:)`, one
  string literal, `Workspace.init(from:)`, a field per line, and
  `AppModel.reply(to:)`, one case per control request; `WorkspaceStore` passes
  400 lines because every writer of its `private(set)` state must live in the
  file. `closure_body_length` is off: a SwiftUI `Form` is one closure.
- **Names are three letters or more**, bar `a`, `b`, `c`, `x`, `y`, `i`, `id`,
  `at`, `on`, `to`, `up`, `fd` and the persisted `_0`.
- **Members sit in SwiftLint's `type_contents_order`**: cases, type aliases,
  nested types, static then instance properties, initializers, static then
  instance methods, subscripts, `deinit`. Defaulted parameters come last.
- **Enum cases are alphabetical unless the order means something**: what a
  picker, the board, a strip or the helper's usage error lists in that order,
  the order file lists are placed or a create or remove's stages run, the badge
  fit's widest-first, and `ANSIColor`, whose raw value is the palette index.
  Each such enum is marked with its reason. SwiftLint checks top-level enums
  only; a nested one follows the rule unchecked and unmarked.
- **A type's extension in its own file is folded into it**, except where it
  keeps a memberwise init synthesized, and `WorkspaceStore`'s concerns, which
  must share its file. Those are marked.
- **`prefer_key_path` is off in tests**: `#expect` cannot expand a key path
  passed as its call's function, as `allSatisfy(\.isEmpty)` would be.
- **SwiftLint's analyzer is not run.** Tried on 2026-10-09: over 30 minutes for
  one pass, `unused_declaration` found 4 and all 4 were wrong (a `@State` read
  through `$`, a protocol witness, a kept-alive `let`), and `unused_import`
  mostly asked for `Darwin` where `Foundation` already brings it. It needs
  SwiftPM's `@file` source lists expanded by hand, too. `MemberImportVisibility`
  already fails the build on a missing import.

## Before you say something works

- **Format what you touched, then lint, test, build and release.** All pass, no
  warnings.

## Driving a debug build

- **The command line drives a running copy without a click**, from opening tabs
  and typing in a pane to reading Debug Info and writing a screenshot;
  `multishell help` lists it. Each helper drives only its own build's app, so
  call `build/Multishell.app/Contents/Helpers/multishell`, not the `multishell`
  on PATH, which belongs to whichever build installed it (state-on-disk.md).
- **`multishell info` lists what is up**: an alert or dialog stalls a script
  that cannot click, and `multishell ui dismiss` cancels the topmost.
- **Look with `multishell debug screenshot`**, which writes a new PNG under
  `/tmp` and prints `{"path": …}`, then read it. It is the app drawing itself,
  terminals included, and needs no permission.
- **Run it against a scratch home, never the account's.** A launch writes the
  state directory, re-points the helper links the installed app's hooks use, and
  its shells write history. `CFFIXED_USER_HOME` moves Foundation's home and
  `HOME` the helper's, so set both on the app and on every helper call.
- **A pane's shell still runs as the account**: the engine starts it through
  `/usr/bin/login -flp`, which sets `HOME` from the account, so it reads the
  real startup files and writes the real history. Typing into a pane in a
  scratch run wrote `~/.zsh_history`; drive the app without typing into panes.
- **Keep that home's path short**, a symlink from `/tmp` to the scratch
  directory: the socket sits under it, and `sun_path` holds 104 bytes.
- **Launch the binary itself**, `build/Multishell.app/Contents/MacOS/Multishell`
  under `env -i` with those two variables, not `open` or `multishell open`:
  LaunchServices passes no environment. Wait until `multishell info` answers,
  and end with `multishell quit --force`.
- **Turn `trashesRemovedWorktrees` off first** where a run removes worktrees, or
  they land in the account's Trash.

## What you cannot verify

- **You cannot drive the app's desktop.** No Apple events, no screen recording.
  Do not try, and do not ask for those permissions; the command line and its
  screenshots are the way in.
- **You can lay a view out in-process.** A hosting view inside a window that is
  never ordered in measures and renders, asking for nothing, and the sizing
  options give the size SwiftUI would refuse to go below.
  ViewSettingsWindowTests is the pattern.
- **It still needs a window server**, which is a session rather than a
  permission; CI's runner has one.
- **A tab band is drawn outside the AppKit hierarchy**: in no bitmap and in no
  measured size, so a band that clips stays invisible here.
- **The image renderer refuses a tab view outright** and draws a placeholder,
  where the AppKit display path renders the tab's content.
- **A minimum width reports where text stops wrapping**, not where a control is
  cut off, so it reads as a clip for any page with a caption.
- **A terminal's frame is an IOSurface on its layer**, which `ViewScreenshot`
  draws under AppKit's cached view, clear there: that is how `debug screenshot`
  shows terminals with their focus ring, checked on a debug build. An in-process
  render of a view has no live terminal to show.
- **Otherwise a view change stops at the checks above**: say what is unverified
  and leave the looking to the user. BUGS.md takes no entry for it, since
  whether a feature draws and works is checked by hand as it is built.

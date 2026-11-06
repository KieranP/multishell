# Building locally

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
- **And fetches the tree-sitter grammars**, into `.build/grammars`: about 2 s
  cold, nothing while the pins are unchanged. A bare `swift build` needs
  `make grammars` first, the package naming each grammar by path
  (dependencies.md).
- **The Info.plist is a template filled in by placeholder**, and
  InfoPlistTemplateTests reads it out of the checkout
  (tests/interface-and-terminal.md). Substitution is bash's own, so a value may
  hold a newline or an ampersand unescaped. The replacement is quoted because
  bash 5.2 and later read an unquoted `&` as the placeholder, and the assignment
  is not, because 3.2 then keeps the quotes.
- **A worktree's name is spelled down to safe characters** before it reaches the
  Info.plist: an unescaped ampersand in a branch name makes the file
  unparseable, and a bundle whose Info.plist will not parse does not launch.
- **The language list is built from the app half's folders alone**, which is
  what makes a language pickable in System Settings. The libraries' half has to
  keep pace, or the app draws its windows translated and says the model's words
  in English.
- **`make signing-identity` creates the self-signed certificate** that keeps
  permission grants across rebuilds; it is not for distribution
  (design/signing.md). `MULTISHELL_SIGN_IDENTITY` picks another certificate, for
  the build and for `make signing-identity` alike, and `-` forces ad hoc.
- **Every target works the same from a git worktree**, and two can build at
  once: the scratch directories are per-worktree and the shared caches lock only
  briefly. Each worktree has its own clone of the submodule, so a new one's
  first libghostty build starts with no `.zig-cache/` or `zig-pkg/`.
- **A worktree the app creates gets libghostty and the grammars copied in**,
  through `.multishell.json`'s `copiedPaths`, so its first build skips Zig: 10 s
  for the submodule clone against about 80 s. The package build is not copied.
  Swift Build recompiles everything when the checkout's path changes: a clone of
  main's `.build` built in 78 s, 82 s with every mtime matched, against 90 s
  from nothing, as measured here on 2026-10-29.
- **Bundle builds of one tree run one at a time**, under a lock file in
  `build/`. A debug build's opening `rm -rf` once emptied `Contents/MacOS` in a
  release build that went on to sign and install the bundle with no binary. The
  install copy runs under the same lock, so `make install` passes its
  destination to `make-app.sh` rather than copying afterwards.
- **`sign` refuses a bundle without its executable**: codesign seals one, and
  `codesign --verify` passes it, but Finder says it is damaged.
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

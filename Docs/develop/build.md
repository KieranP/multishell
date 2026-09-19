# Building, running, verifying

## Requirements

Xcode 26 with Swift 6 (`sudo xcode-select -s /Applications/Xcode.app` if only
the command line tools are active; the app build runs `xcodebuild`, which the
command line tools alone do not have). `git` on PATH. `prettier` for the
Markdown half of `make format`, `brew install prettier`. CI does not run it; the
Claude Code hook `.claude/hooks/format-markdown.sh` runs it on every `.md` the
agent writes.

## Build, test, run

```sh
make signing-identity  # once per machine, before the first build
make test              # libraries and model, then the Mac hosts
make test-app          # compile the macOS app without bundling
make build             # -> build/Multishell.app; CONFIG=release for optimised
make release           # the same, optimised
make run               # build and open it
make install           # release build to /Applications (INSTALL_DIR= to change)
make format            # rewrite to project style; run before reading a diff
make lint              # what CI runs, --strict: a warning fails
```

`Scripts/make-app.sh` builds the app binary with `xcodebuild` (below), wraps it
in a bundle, copies the SwiftPM resource bundles into `Contents/Resources`
(libghostty's terminfo must be there), builds the CLI the same way into
`Contents/Helpers`, writes the Info.plist and signs both.
`CFBundleShortVersionString` = `<commit date>-<short sha>`, `-dirty` for a
modified tree; `CFBundleVersion` = the commit count, that key taking digits and
dots only. First app build downloads the libghostty xcframework, ~80 MB.

`Scripts/build-lib.sh` holds the parts that drive xcodebuild and codesign, and
is sourced, not run. What stays in `make-app.sh` is what is particular to this
bundle: the paths, the version and the worktree variant. The Info.plist is a
template, `Apps/macOS/Resources/Info.plist.in`, filled in by placeholder;
BundleDeclarationTests reads it out of the checkout (tests.md). Substitution is
bash's own, so a value may hold a newline or an `&` without escaping.

Three things the scripts do that their code cannot say. macOS needs a bundle for
a Dock icon, activation and the menu bar, and SwiftPM emits an executable
instead. A worktree's name is spelled down to letters, digits, `_` and `-`
before it reaches the Info.plist, because an unescaped `&` in a branch name
makes the whole file unparseable and a bundle whose Info.plist will not parse
does not launch. And `CFBundleLocalizations` is built from the app half's
`.lproj` folders alone, which is what makes a language pickable in System
Settings; the libraries' half has to keep pace, or the app draws its windows
translated and says the model's words in English.

`make signing-identity` creates the self-signed `Multishell Dev` certificate;
without it the build signs ad hoc and says so. Not for distribution: it is so
the user's permission grants survive a rebuild.

Every target works the same from a git worktree as from the checkout, and two
worktrees can build at once: the scratch directories are per-worktree and the
shared SwiftPM caches only lock briefly. Running the tests is the exception,
several of their bounds being wall-clock. So `make test` compiles with
`--build-tests`, unguarded, then runs with `--skip-build` under `lockf` on
`~/Library/Caches/multishell-test.lock`: a second worktree compiles alongside
the first and waits, without saying so, only for its turn to run. A bare
`swift test` takes no lock. Nothing caps the compiler's own parallelism, so
three full builds at once still oversubscribe the machine; `-j` if that bites.

A debug bundle built in a worktree names that worktree in its state file and
socket (`state-on-disk.md`), so two of them can run at once.

## Why the app is built through xcodebuild

`swift build` under Xcode 26 wrote the tree's own `Apps/macOS/.build` path into
the binary as the place `Bundle.module` looks after the app root, never
`Contents/Resources`, and codesign refuses anything at the app root, symlink
included. An installed app then read libghostty's terminfo from the build
directory, and the next build there took it away: every new shell started with
`TERM=xterm-ghostty` and no entry for it, so `less` warned that the terminal is
not fully functional, zsh drew doubled letters and lost key combinations, and a
relaunch trapped on the first terminal. Xcode's own build of the same package
generates an accessor that looks in `Contents/Resources` first and writes no
path, under Xcode 26 and 27 alike, so `make-app.sh` runs `xcodebuild` for the
app binary and refuses one that carries a build path. Xcode 27's `swift build`
writes no path either, but the floor stays at 26, which the tests build under.
The CLI reads MultishellCore's catalogue on every hook, so it would fail the
same way; it too comes from `xcodebuild`, on the root package's `multishell`
scheme into `.build/xcode`, and goes through the same three checks as the app
binary. Only Xcode 27 has run this; nobody has built it under 26.

The three checks pipe into `grep -c` rather than `grep -q`: under `pipefail` a
`-q` that quits at its first match leaves `strings` writing into a closed pipe,
SIGPIPE makes the pipeline's status 141, and the `if` reads a match as a miss.
With 1.3 MB of strings against a 64 KB pipe buffer, the check could only ever
fire on a match in the last 64 KB.

Two things the auto-generated package scheme does that the script undoes. It
signs, ad hoc, which the script does itself afterwards with the certificate, so
`CODE_SIGNING_ALLOWED=NO`. And it compiles every configuration, release
included, with `-profile-generate`, so the binary carried seven `__llvm_prf`
sections, ran instrumented and tried to write a profile at exit.
`-enableCodeCoverage NO` is refused outside a test action;
`CLANG_COVERAGE_MAPPING=NO` is the setting that turns it off, and the script
checks the sections are gone rather than trusting it.

Two more the script works around. No destination names plain macOS alone:
libghostty-spm declares Mac Catalyst, so `platform=macOS` matches both and
xcodebuild warns that it is using the first, `variant=macOS` is refused, and a
package build without `-destination` is refused. The first is plain macOS in
every run so far, and the script checks the binary's `LC_BUILD_VERSION` says so
rather than trusting the order. And `-quiet` prints "failed with exit code 0"
for a compile that only warned, so each run is written to that package's
`.build/xcode/xcodebuild-<Configuration>.log` instead, shown whole on failure,
and on success only its `warning:` and `error:` lines, one each. Cost:
xcodebuild keeps its own directory under each package's `.build/xcode`, so both
the app and the libraries compile twice for anyone running `make test` and
`make build`.

CI: three jobs on `macos-15`, in parallel: `swift build` and `swift test` for
the root package, the same for `Apps/macOS`, and `make lint`. CI runs
`swift test` directly, so it takes no lock.

## Before you say something works

`make format` on what you touched, then `make lint`, `make test` (both
packages), `make build`, `make release`. All pass, no warnings.

## What you cannot verify

You cannot see or drive the app: no Apple events (System Events answers
`-1743`), no Screen Recording (`screencapture` cannot make an image). Do not
try, do not ask for those permissions.

What you can do instead: lay a view out in-process. An NSHostingView inside an
NSWindow that is never ordered in measures and renders, asking for nothing, and
`sizingOptions = [.minSize, .intrinsicContentSize]` then gives the size SwiftUI
would refuse to go below. SettingsPageSizeTests is the pattern. It still needs a
window server, which is not a permission but is a session; CI's `macos-15`
runner has one, the page tests passing there.

Four limits found doing it. A TabView's band is drawn outside the AppKit
hierarchy: it is in no bitmap and in no measured size, so a band that clips
stays invisible here. ImageRenderer refuses a TabView outright and draws a
placeholder in its place, where `cacheDisplay` renders the tab's content. A
minimum width reports where text stops wrapping, not where a control is cut off,
so it reads as a clip for any page with a caption. Metal is untried: a Ghostty
surface is expected to come out blank, since neither path captures a drawable,
but nobody has looked.

A view change otherwise stops at the checks above: say what is unverified, leave
the looking to the user, and record it in `known-gaps.md` with the fallback if
it turns out wrong. Anything decidable without a screen belongs in a plain value
in MultishellAppCore, tested there.

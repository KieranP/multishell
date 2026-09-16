# Building, running, verifying

## Requirements

Xcode 26 with Swift 6 (`sudo xcode-select -s /Applications/Xcode.app` if only
the command line tools are active; the app build runs `xcodebuild`, which the
command line tools alone do not have). `git` on PATH.

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

`Scripts/make-app.sh` builds the app binary with `xcodebuild` (below), wraps
it in a bundle, copies the SwiftPM resource bundles into `Contents/Resources`
(libghostty's terminfo must be there), builds the helper with `swift build`
into `Contents/Helpers`, writes the Info.plist and signs both.
`CFBundleShortVersionString` = `<commit date>-<short sha>`, `-dirty` for a
modified tree; `CFBundleVersion` = the commit count, that key taking digits
and dots only. First app build downloads the libghostty xcframework, ~80 MB.

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

`swift build` under Xcode 26 wrote the tree's own `Apps/macOS/.build` path
into the binary as the place `Bundle.module` looks after the app root, never
`Contents/Resources`, and codesign refuses anything at the app root, symlink
included. An installed app then read libghostty's terminfo from the build
directory, and the next build there took it away: every new shell started with
`TERM=xterm-ghostty` and no entry for it, so `less` warned that the terminal
is not fully functional, zsh drew doubled letters and lost key combinations,
and a relaunch trapped on the first terminal. Xcode's own build of the same
package generates an accessor that looks in `Contents/Resources` first and
writes no path, under Xcode 26 and 27 alike, so `make-app.sh` runs
`xcodebuild` for the app binary and refuses one that carries a build path.
Xcode 27's `swift build` writes no path either, but the floor stays at 26.

Two things the auto-generated package scheme does that the script undoes.
It signs, ad hoc, which the script does itself afterwards with the
certificate, so `CODE_SIGNING_ALLOWED=NO`. And it compiles every
configuration, release included, with `-profile-generate`, so the binary
carried seven `__llvm_prf` sections, ran instrumented and tried to write a
profile at exit. `-enableCodeCoverage NO` is refused outside a test action;
`CLANG_COVERAGE_MAPPING=NO` is the setting that turns it off, and the script
checks the sections are gone rather than trusting it.

Two more the script works around. No destination names plain macOS alone:
libghostty-spm declares Mac Catalyst, so `platform=macOS` matches both and
xcodebuild warns that it is using the first, `variant=macOS` is refused, and
a package build without `-destination` is refused. The first is plain macOS
in every run so far, and the script checks the binary's `LC_BUILD_VERSION`
says so rather than trusting the order. And `-quiet` prints "failed with exit
code 0" for a compile that only warned, so the run is written to
`Apps/macOS/.build/xcode/xcodebuild-<Configuration>.log` instead, shown whole
on failure, and on success only its `warning:` and `error:` lines, one each.
Cost: xcodebuild keeps its own directory under `Apps/macOS/.build/xcode`, so
the app compiles twice for anyone running both `make test` and `make build`.

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

What you can do instead: lay a view out in-process. An NSHostingView inside
an NSWindow that is never ordered in measures and renders, asking for nothing,
and `sizingOptions = [.minSize, .intrinsicContentSize]` then gives the size
SwiftUI would refuse to go below. SettingsPageSizeTests is the pattern. It
still needs a window server, which is not a permission but is a session: it
passes on a developer's machine, and whether CI's runner has one is unchecked
as of the first such test.

Four limits found doing it. A TabView's band is drawn outside the AppKit
hierarchy: it is in no bitmap and in no measured size, so a band that clips
stays invisible here. ImageRenderer refuses a TabView outright and draws a
placeholder in its place, where `cacheDisplay` renders the tab's content.
A minimum width reports where text stops wrapping, not where a control is cut
off, so it reads as a clip for any page with a caption. Metal is untried: a
Ghostty surface is expected to come out blank, since neither path captures a
drawable, but nobody has looked.

A view change otherwise stops at the checks above: say what is unverified,
leave the looking to the user, and record it in `known-gaps.md` with the
fallback if it turns out wrong. Anything decidable without a screen belongs in
a plain value in MultishellAppCore, tested there.

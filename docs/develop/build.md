# Building, running, verifying

How to build and test, and the limit of what an agent can check.

## Requirements

Xcode 26 with Swift 6 (`sudo xcode-select -s /Applications/Xcode.app` if only
the command line tools are active). `git` on PATH.

## Build, test, run

    make signing-identity  # once per machine, before the first build
    make test              # libraries and model, then the Mac hosts
    make test-app          # compile the macOS app without bundling
    make build             # -> build/Multishell.app; CONFIG=release for optimised
    make run               # build and open it
    make install           # release build to /Applications (INSTALL_DIR= to change)
    make format            # rewrite to project style; run before reading a diff
    make lint              # what CI runs, --strict: a warning fails

`Scripts/make-app.sh`: wraps the SwiftPM binary in a bundle, copies SwiftPM
resource bundles into `Contents/Resources` (libghostty's terminfo must be
there), builds the helper into `Contents/Helpers`, signs both. Version written
= the commit built from, `-dirty` for a modified tree. First app build
downloads the libghostty xcframework, ~80 MB.

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
`swift test` takes no lock. Nothing caps the compiler's own parallelism
either, so three full builds at once still oversubscribe the machine; `-j` if
that bites.

A debug bundle built in a worktree names that worktree in its state file and
socket (`state-on-disk.md`), so two of them can run at once. It still reads
its resources from that worktree, which the build says as it finishes
(`known-gaps.md` has why).

CI: builds and tests libraries and app on macOS, then `make lint`.

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

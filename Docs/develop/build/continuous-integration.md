# Continuous integration

- **CI runs on GitHub's `xcode-27` image**, a preview, for the toolchain
  development uses; the `macos-26` default had Xcode 26.6. Nothing builds with
  Xcode 26 any more, though COMPAT.md still names it as the floor.
- **CI runs two jobs in parallel**: build and test, and the lint. It runs on a
  push to main and on a pull request, so a branch with no pull request goes
  untested and one with a pull request runs once per push. It calls `swift test`
  directly, so it takes no lock and has no write sandbox: a test writing outside
  the temporary directories passes there. It shares only the one-test-per-core
  cap with `make test`, and a run past 60 minutes is stopped. libghostty's cache
  is saved as soon as it is built, so a red run still keeps it; a cold build's
  time on CI is unmeasured. It builds the package without debug info, which took
  a cold build from 38 s to 29 s here, so a crash backtrace from CI has no line
  numbers, and without the index store, which only an editor reads: 97 s to 88 s
  at three jobs here, under the native build system.
- **CI restores the last package build and dates each file by its last commit**,
  `Scripts/restore-mtimes.sh`. A checkout dates every file at the moment of
  checkout, so a restored `.build` would recompile everything. Dated, one
  commit's change rebuilt in 44 s against 136 s cold at three jobs here under
  Swift Build, and in either direction through history; on CI a warm build took
  61 to 76 s against 4m45s cold. The compiler's
  `-enable-incremental-file-hashing` is no substitute: undated, an unchanged
  tree rebuilt in 31 s against 2 s dated. A shallow clone gives every file one
  date, so the script deepens one first, and not the submodule's 100 MB. A pull
  request's merge dates what it brought in by itself, or a file both sides
  changed would keep main's date and go unrebuilt. The toolchain's version and
  libghostty's fingerprint key the cache: restored across patch 0007, the build
  compiled against the old GhosttyKit headers and failed, so a new libghostty
  costs one cold package build. Only a push to main saves one: at 400 MB a run,
  pull requests saving theirs had the repository at 8.9 of its 10 GB, where
  GitHub evicts the least recently used, libghostty's included. setup-zig caches
  nothing for the same reason.
- **CI's test step is bound by the runner's three cores**, so the targets run
  one after another, as Swift Build runs them. AppCore beside the rest as two
  `swift test` processes took 3m48s against 3m52s, AppCore's own run going from
  99 s to 193 s; one process per target took 8m22s, each loading every bundle.
- **The manifests' cache is `.build`'s own** (`--manifest-cache local`), so the
  restored build carries it; SwiftPM's shared one sits outside the cache.
- **A CI step that writes a script's output to `$GITHUB_OUTPUT` assigns it to a
  variable first.** A failing script inside `echo`'s `$(...)` leaves the step
  green, which once gave the build an empty Zig version and cache key.

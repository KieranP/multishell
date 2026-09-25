# Dependencies

- **`THIRD-PARTY-NOTICES.md` is written from the bundle, not the dependency
  graph.** A transitive dependency compiled into the executable needs its notice
  there and its licence text verbatim in `Licenses/` (MSDisplayLink is one); a
  file shipping its own licence beside it (bash-preexec) is pointed at. Adding a
  dependency means deciding which.
- **Most of what ships comes inside the prebuilt `libghostty.a`**: Ghostty's Zig
  packages, its C libraries and two fonts. The executable is stripped, so tell
  what the linker kept from the archive's members (`lipo -thin`, then `ar -t`),
  the undefined symbols of its Zig object (`nm -u libghostty_zcu.o`), and
  strings a library leaves in the executable, such as a font's name table or a
  library's error messages. Moving the libghostty pin means redoing that.
- **libghostty via `Lakr233/libghostty-spm`**, MIT, pinned to an exact tag, the
  embedding API not being stable. Prebuilt by a third party with patches; build
  it from source before distributing.
- **It carries Ghostty itself, bash-preexec, and most of the libraries and fonts
  the notices list.** Its `GhosttyTheme` product, the iTerm2 colour schemes, is
  not linked and ships nothing.
- **Ghostty's own bash and zsh integration is GPLv3.** The package ships an MIT
  rewrite and a script that refuses GPL text, which is what keeps this
  repository's AGPL from inheriting a GPL obligation.
- **Moving the pin changes which config keys a user's Ghostty file may use**,
  and can change which file names it reads, so `GhosttyUserConfig` wants a look
  then. The key list came from Ghostty's own `show-config` and `docs` output,
  each key handed to the pinned build to see whether it took it; the names and
  their order came from its `loadDefaultFiles`.
- **MSDisplayLink via `Lakr233/MSDisplayLink`**, MIT. Easy to miss: this tree
  imports it nowhere and names it in no manifest, but libghostty-spm depends on
  it and its symbols are in the executable. libghostty-spm asks only for
  `from: "2.2.0"`, so `Package.resolved` alone pins it, and a
  `swift package update` can move it without the libghostty pin moving.
- **swift-subprocess starts every child but a terminal's**, Apache-2.0, from
  1.0.0. Each runs in a session of its own, so no child has a controlling
  terminal: an interactive shell on one, outside its foreground group, stops
  itself on SIGTTIN. The session is a `POSIX_SPAWN_SETSID` flag, not
  `createSession`, which forks the whole app before each spawn and retries no
  refused fork. Four parts stay ours. Its teardown stops once the direct child
  exits, which let a grandchild trapping SIGHUP live on, so `ProcessStopper`
  signals the group itself. It offers no hook between a child's exit and its
  reap, so the runner watches for the exit and marks it first, or a stop could
  signal a reused pid. Its answer to a cancelled task is SIGKILL, so each run is
  shielded from cancellation (design/architecture.md). The runner opens its own
  pipes: at the descriptor limit Subprocess traps on a pipe it opened when the
  next open fails (its `Configuration.swift:1115`), where ours throw. Owning
  them, it reads them too, and gives up a second after exit on an EOF a
  background grandchild withholds. Subprocess's collectors have stopped at the
  exit since 0.5, so the trap is the whole reason; DescriptorExhaustionTests
  shows it.
- **swift-system comes with it**, not named here but linked all the same;
  Subprocess's paths are Apple's own `System` types, which is what this code
  imports.
- **CryptoKit hashes the shared-settings files**, not swift-crypto: on the Mac
  that package only re-exports CryptoKit, and would add a notice to ship.
- **git 2.36 or newer**, for `-z` on `git worktree list --porcelain`, which
  keeps a path holding a newline from reading as two records. The floor is under
  what the supported macOS ships, so an older git usually comes from a version
  manager. That git refuses `-z` with status 129 and `WorktreeGit` asks for the
  newline form, losing only such a path
  (`aGitThatRefusesTheNulFormIsAskedForTheNewlineOne`). Under 2.31 `rev-parse`
  echoes `--path-format=absolute` back and answers relative, and `WorktreeGit`
  resolves the answer
  (`aCheckoutIsRemovedWithItsHooksOnAGitThatPredatesPathFormat`).
- **prettier**, for the Markdown in `make format` and the Claude Code hook, not
  in CI. From Homebrew rather than a `package.json`: there is no Node toolchain
  here and a `node_modules` for one formatter is more than the docs are worth.
- **`proseWrap: always` is what reflows to 80 columns.** Prettier pads a table
  row to its widest cell whatever `printWidth` says, and refuses a symlink, so
  the hook skips one and `CLAUDE.md` is formatted through `AGENTS.md`.

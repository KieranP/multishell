# Dependencies

- **`THIRD-PARTY-NOTICES.md` is written from the bundle, not the dependency
  graph.** A dependency compiled into the executable needs its notice there and
  its licence text verbatim in `Licenses/`. Adding a dependency means deciding
  which.
- **Most of what ships comes inside `libghostty.a`**: Ghostty's Zig packages,
  its C libraries and two fonts. The debug build's executable is not stripped,
  so `nm --defined-only` on it says which libraries the linker kept, and a
  font's name table, in UTF-16, which fonts. Moving the Ghostty pin or a patch
  means redoing that.
- **The archive also holds FreeType, libpng and zlib, which the linker drops**:
  at `befcdfd` the debug executable defines none of `FT_Init_FreeType`,
  `png_create_read_struct`, `inflate` or `deflate`, while it keeps `onig_new`.
  So the notices leave them out.
- **libghostty is built here from Ghostty itself**, the `ThirdParty/ghostty`
  submodule, by `Scripts/build-ghostty.sh`. The submodule's commit is the pin,
  the embedding API not being stable.
- **`Lakr233/libghostty-spm` was dropped for it.** Its libghostty came prebuilt
  by a third party, with GNU libintl, LGPL, inside, which left open how a user
  would relink it; its Swift wrapper also dropped the search counts and kept the
  selection to itself (design/terminals.md). `Lakr233/DisplayLink`, which only
  it depended on, went with it, and so did the bash-preexec it shipped.
- **The patches in `ThirdParty/ghostty-patches/` came from libghostty-spm**,
  MIT, cut as plain diffs against the pin, each with its reasons in its own
  header: scroll remainder, synchronized output kept across a resize, and the
  frame held while a prompt redraws. The last two are what stop the prompt line
  blinking on a resize.
- **Its Xcode 27 libtool patch was dropped at `befcdfd`**: upstream's
  `a83a82b3f` normalises the archives before the merge itself, and a build
  without it gave the same archive, member for member.
- **Two more leave out what the app never uses**: custom shaders and the
  inspector. Built with them, the executable keeps glslang, SPIRV-Cross and Dear
  ImGui, and the inspector's calls make the linker keep FreeType, libpng and
  zlib too. Built without, the notices stay as short as they are. A user's
  `custom-shader` line is dropped with them, having nothing to run.
- **i18n is off**, which is what keeps GNU libintl, LGPL, out of the executable:
  Ghostty's Zig object then calls no gettext function, and the linker drops the
  archive's copy. The app's words are its own anyway.
- **A patch that no longer applies stops the build** and names itself. Moving
  the pin means cutting each again, in order, in a scratch clone at the new
  commit: `git apply --3way` merges where upstream only moved the lines around
  it, the rest is resolved by hand, and after a commit `git diff HEAD~1` under
  the old header is the new patch. One the pin already has is deleted; the build
  refuses it.
- **The build itself applies them strictly**, never three-way: a merge it made
  unseen could build code nobody read.
- **The build moves the submodule to the pin** when it is empty or behind, as
  after a plain clone or a pull that moved the pin, where it would otherwise
  build the old Ghostty and fail later as Swift that no longer compiles.
- **A checkout past the pin stops the build** instead, since it may be a bump in
  progress that an update would throw away. A branch pinned earlier, or a pull
  that moves the pin back, stops it too:
  `git submodule update ThirdParty/ghostty` matches the pin, where in a bump
  `git add ThirdParty/ghostty` makes the checkout the pin, once the patches
  apply to it.
- **The build leaves the submodule clean**: it writes there only where Ghostty's
  `.gitignore` covers, and takes its patches back out.
- **It also installs `libghostty-vt` under `lib/` and editor and shell files
  under `share/`**, none of which the app uses. Ghostty's build installs them
  whatever the options, leaving them out would take another patch, and none
  reaches the bundle.
- **One build at a time per worktree**, under `lockf`: two at once reverted the
  patches under each other and deleted each other's output.
- **Ghostty's bash and zsh integration scripts are GPLv3 and are not shipped**;
  its integration is off and ours does that work (design/terminals.md).
- **Moving the pin changes which config keys a user's Ghostty file may use**,
  and can change which file names it reads, so `GhosttyConfigAllowList` and
  `GhosttyUserConfig` want a look then. The key list came from Ghostty's own
  `show-config` and `docs` output, each key handed to the pinned build to see
  whether it took it; the names and their order came from its
  `loadDefaultFiles`.
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
- **libproc and the kernel's process sysctls read the process table**, from
  libSystem, so they need no package and no notice. Apple documents neither, and
  `libproc.h` calls its interfaces private and subject to change. The helper's
  agent hooks rest on `proc_listchildpids` and `KERN_PROCARGS2`, the debug tools
  on `proc_pid_rusage` too, so a new macOS wants both tried. The quirks found so
  far are in design/debug-tools.md.
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

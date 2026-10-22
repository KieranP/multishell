# Dependencies

- **`THIRD-PARTY-NOTICES.md` is written from the bundle, not the dependency
  graph.** A dependency compiled into the executable needs its notice there and
  its licence text verbatim in `Licenses/`. Adding a dependency means deciding
  which.
- **Most of what ships comes inside `libghostty.a`**: Ghostty's Zig packages,
  its C libraries and two fonts. The debug executable is not stripped, so
  `nm --defined-only` on it says which libraries the linker kept, and a font's
  name table, in UTF-16, which fonts. Moving the Ghostty pin or a patch means
  redoing that.
- **The archive also holds FreeType, libpng and zlib, which the linker drops**:
  at `ad97d33` the debug executable defines none of `FT_Init_FreeType`,
  `png_create_read_struct`, `inflate` or `deflate`, while it keeps `onig_new`.
  So the notices leave them out.
- **libghostty is built here from the `ThirdParty/ghostty` submodule** by
  `Scripts/build-ghostty.sh`. The submodule's commit is the pin, the embedding
  API not being stable.
- **`Lakr233/libghostty-spm` was dropped for it.** Its libghostty came prebuilt
  by a third party with GNU libintl, LGPL, inside, which left open how a user
  would relink it; its Swift wrapper also dropped the search counts and kept the
  selection to itself (design/terminals.md). `Lakr233/DisplayLink`, which only
  it depended on, went with it, and so did the bash-preexec it shipped.
- **The patches in `ThirdParty/ghostty-patches/` came from libghostty-spm**,
  MIT, cut as plain diffs against the pin, each with its reasons in its own
  header: scroll remainder, synchronized output kept across a resize, and the
  frame held while a prompt redraws. The last two are what stop a pane blinking
  on a resize, the whole pane while a program repaints and the prompt line while
  the shell redraws it.
- **Its Xcode 27 libtool patch was dropped at `befcdfd`**: upstream's
  `a83a82b3f` normalises the archives before the merge itself, and a build
  without it gave the same archive, member for member.
- **Two more leave out what the app never uses**: custom shaders and the
  inspector. Built with them, the executable keeps glslang, SPIRV-Cross and Dear
  ImGui, and the inspector's calls make the linker keep FreeType, libpng and
  zlib too. A user's `custom-shader` line is dropped, having nothing to run.
- **0006 is ours**: `ghostty_surface_memory_usage`, a surface's terminal bytes
  for the debug tools (design/debug-tools.md), asked for upstream in
  ghostty-org/ghostty discussion #14524. Delete it once the pin has a
  surface-level call.
- **i18n is off**, which keeps GNU libintl, LGPL, out of the executable:
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
- **The build moves the submodule to the pin when it is empty or behind**, as
  after a plain clone or a pull that moved the pin; otherwise it would build the
  old Ghostty and fail later as Swift that no longer compiles.
- **A checkout past the pin stops the build** instead, since it may be a bump in
  progress that an update would throw away. A branch pinned earlier, or a pull
  that moves the pin back, stops it too:
  `git submodule update ThirdParty/ghostty` matches the pin, where in a bump
  `git add ThirdParty/ghostty` makes the checkout the pin, once the patches
  apply to it.
- **The build leaves the submodule clean**: it writes there only where Ghostty's
  `.gitignore` covers, and takes its patches back out.
- **It also installs `libghostty-vt` under `lib/` and editor and shell files
  under `share/`**, none of which reaches the bundle. Ghostty's build installs
  them whatever the options, and leaving them out would take another patch.
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
  refused fork.
- **Four parts stay ours.** Its teardown stops once the direct child exits,
  which let a grandchild trapping SIGHUP live on, so `ProcessStopper` signals
  the group itself. It offers no hook between a child's exit and its reap, so
  the runner marks the exit first, or a stop could signal a reused pid. It
  answers a cancelled task with SIGKILL, so each run is shielded from
  cancellation (design/architecture.md). The runner opens its own pipes: at the
  descriptor limit Subprocess traps on a pipe it opened when the next open fails
  (its `Configuration.swift:1115`), where ours throw. Owning them, it reads them
  too (design/architecture.md). Subprocess's collectors have stopped at the exit
  since 0.5, so the trap is the whole reason; DescriptorExhaustionTests shows
  it.
- **swift-system comes with it**, linked though not named here; Subprocess's
  paths are Apple's own `System` types, which is what this code imports.
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
- **prettier formats the Markdown** for `make format` and the Claude Code hook.
  From Homebrew rather than a `package.json`: there is no Node toolchain here,
  and a `node_modules` for one formatter is more than the docs are worth.
- **`proseWrap: always` is what reflows to 80 columns.** Prettier pads a table
  row to its widest cell whatever `printWidth` says, and refuses a symlink, so
  the hook skips one and `CLAUDE.md` is formatted through `AGENTS.md`.
- **Highlighting is SwiftTreeSitter 0.25.0 over the tree-sitter runtime
  0.25.10**, both pinned exactly, the runtime named too for its `TreeSitter`
  module. SwiftTreeSitter's newest tag, 0.10.0 from February 2026, sorts below
  0.25.0, and it and the main branch still pin tree-sitter 0.25.x, which bounds
  a grammar's language ABI to 13 to 15.
- **Each grammar is its own Swift package, pinned to a tagged commit carrying
  its generated parser**, its highlights query read from that package's resource
  bundle, which the bundling script copies with every other. Most repositories
  commit no `parser.c` on their main branch; tree-sitter-swift's tags it
  `<version>-with-generated-files`.
- **The grammars come as GitHub's archive of each pinned commit, not as git
  clones**: `Scripts/fetch-grammars.sh` downloads and unpacks them into
  `.build/grammars/`, which `Package.swift` names by path. SwiftPM clones a
  package's whole history and has no shallow clone, and most grammar
  repositories commit every regenerated `parser.c`, so the clones came to 1.7
  GB, Ruby's 367 MB and Kotlin's 303 MB, and took 8.6 minutes of a 13-minute CI
  build, Kotlin's alone 334 s (2026-10-22). The 25 archives are 0.04 to 3.8 MB
  and arrive in about 2 s.
- **A bump is the grammar's row in the script**: its tag, the commit, and the
  SHA-256 of `https://codeload.github.com/<owner>/<repo>/tar.gz/<commit>`.
  GitHub has kept these archives byte-stable since 2023, and Homebrew pins them
  the same way. If one ever changes, the fetch stops and prints both sums rather
  than building from it. An archive leaves out git submodules: of the 25 only
  YAML has one, its test suite, which the build never reads; otherwise each
  archive matched its git checkout file for file (2026-10-22).
- **The grammars' own SwiftTreeSitter dependencies are never fetched**: they
  feed only each package's test target, so SwiftPM resolves four packages over
  git, SwiftTreeSitter, the runtime, swift-subprocess and swift-system.
- **CSS's, JavaScript's, Python's and YAML's scanners are copied under
  `ThirdParty/tree-sitter/`**, into one `TreeSitterScanners` target: their
  packages test for `src/scanner.c` against the build's working directory, so as
  a dependency they build without it and fail to link. Only the scanner, the
  headers beside it and the licence are copied, 175 KB against about 8.5 MB for
  the whole grammars. Not every header is included: CSS's and JavaScript's
  scanners take only `parser.h`, the folder kept whole so a bump is a copy. Each
  folder names its tag and commit, which must match the package's pin, and the
  open fixes
  ([javascript#383](https://github.com/tree-sitter/tree-sitter-javascript/pull/383),
  [yaml#46](https://github.com/tree-sitter-grammars/tree-sitter-yaml/pull/46))
  would let a folder go. tree-sitter's own template already tests against
  `Context.packageDirectory`.
- **The scanner target fails its build on a warning**, `treatAllWarnings`
  reaching clang as `-Werror`, the manifest's settings loop not reaching a C
  target; the Python and YAML scanners narrow a `size_t` length to `uint32_t`,
  so the target disables that warning alone.
- **The grammar packages' warnings show in every build but cannot fail it**: a
  path package's are printed where a remote one's were hidden. Kotlin's, SCSS's,
  Svelte's and Swift's manifests exclude files their repositories lack, and
  SQL's scanner narrows a `size_t`.
- **The maintained repository, not the most-starred**: the tree-sitter-grammars
  YAML, TOML, Zig, Make, Svelte and SCSS, whose originals are stale or archived;
  Himujjal's Svelte was last pushed in 2024, serenadeai's SCSS in 2022. Kotlin
  is fwcd's, the most-starred and maintained; SQL is DerekStride's.
- **HTML's package is there for Svelte as much as for `.html`**: Svelte's query
  opens `; inherits: html`, Neovim's convention, so its tags and attributes
  colour only with HTML's query read first. SCSS's query likewise adds to CSS's,
  which is read before it.
- **SCSS's licence text is from the repository's `master`**: its `v1.0.0` tag
  predates the `LICENSE` file (`8f47fa8b`), though its `package.json` and
  `Cargo.toml` at the tag already say MIT.
- **SQL is pinned by revision on its `gh-pages` branch**, the only place it
  commits a generated parser; its tags hold the grammar alone. A bump is the
  newest deploy commit there.
- **C#, C++, Kotlin and SQL are the heavy grammars**, their generated parsers 17
  to 41 MB of C. Those four with Java, PHP and Make took the release binary from
  32.0 MB to 58.6 MB (2026-10-16).
- **HTML, CSS, SCSS and Svelte are light**: 0.36 MB of code and data together in
  a release build, by their objects' `__TEXT` and `__DATA` (2026-10-20), SCSS's
  166 KB the most.
- **Each grammar costs binary size and build time**, Swift's about 4.2 MB, most
  of it parse tables, so the list grows on request; the notices name each with
  the ICU headers the runtime compiles.

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
- **Moving the pin changes which config keys a user's Ghostty file may use**, so
  `GhosttyUserConfig` wants a look then. The list came from Ghostty's own
  `show-config` and `docs` output, each key handed to the pinned build to see
  whether it took it.
- **MSDisplayLink via `Lakr233/MSDisplayLink`**, MIT, pinned. Easy to miss: this
  tree imports it nowhere and names it in no manifest, but libghostty-spm
  depends on it and its symbols are in the executable.
- **`WeightedSplit` uses `_VariadicView`**, an underscored SwiftUI API.
- **git 2.36 or newer**, for `-z` on `git worktree list --porcelain`, which is
  what keeps a path holding a newline from reading as two records. The floor is
  under what the supported macOS ships; a version manager is the way to fall
  under it, and an older git fails the read outright with the row saying so.
- **prettier**, for the Markdown in `make format` and the Claude Code hook, not
  in CI. From Homebrew rather than a `package.json`: there is no Node toolchain
  here and a `node_modules` for one formatter is more than the docs are worth.
- **`proseWrap: always` is what reflows to 80 columns.** Prettier pads a table
  row to its widest cell whatever `printWidth` says, and refuses a symlink, so
  the hook skips one and `CLAUDE.md` is formatted through `AGENTS.md`.
- **The app package names its path dependency** rather than only pointing at it:
  SwiftPM identifies a local package by its directory, which is the branch's
  name in a worktree, so the unnamed form built from the checkout alone.

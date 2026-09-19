# Dependencies

`THIRD-PARTY-NOTICES.md` carries the notices for the code that is actually in
the built app, which `make-app.sh` copies into the bundle beside `LICENSE`. It
is written from reading the bundle, not the dependency graph: a transitive
dependency compiled into the executable needs its notice there (MSDisplayLink is
one), while a file that ships with its own licence beside it (bash-preexec, in
libghostty's resource bundle) is pointed at rather than copied. Adding a
dependency means checking which of the two it is.

- libghostty via `Lakr233/libghostty-spm`, MIT, pinned to an exact tag, the
  embedding API not being stable. Third-party prebuilt with patches; build from
  source with its `Script/build.sh` before distributing. It carries Ghostty
  itself (MIT, Mitchell Hashimoto) and bash-preexec. Its `GhosttyTheme` product,
  which holds the iTerm2 colour schemes, is not linked and ships nothing.
  Ghostty's own bash and zsh integration is GPLv3; the package ships its own MIT
  rewrite instead and has a script that refuses GPL text, which is what keeps
  this repository's AGPL from inheriting a GPL obligation.
  - Moving the pin changes which config keys a user's Ghostty file may use, so
    `GhosttyUserConfig` wants a look then. What was run to write it:
    `ghostty +show-config --default` for the key list, each line handed to the
    pinned build alone, which took 206 of 207. `--docs` on the same command says
    what a key does, and is what the allowed list was decided from.
- MSDisplayLink via `Lakr233/MSDisplayLink`, MIT, pinned at 2.2.0. Easy to miss:
  this tree imports it nowhere and `Apps/macOS/Package.swift` does not name it.
  libghostty-spm depends on it, and its symbols are in the built executable.
- `WeightedSplit` uses `_VariadicView`, an underscored SwiftUI API.
- git, 2.36 or newer. `git worktree list --porcelain -z` is the only call that
  needs it, and `-z` is what keeps a path holding a newline from being read as
  two records; see Docs/design/worktrees.md. The floor is under what the
  supported macOS ships, Sonoma's own being 2.39, but git is looked up on the
  login shell's PATH, so a version manager pinning an older git is the way to
  fall under it. An older one fails the read outright and the project's row says
  so, naming the option.
- prettier, for the Markdown in `make format` and the Claude Code hook, but not
  in CI. From Homebrew rather than a `package.json`: the repository has no Node
  toolchain, and a `node_modules` for one formatter is more than the docs are
  worth. `proseWrap: always` in `.prettierrc` is what reflows a paragraph to 80
  columns; without it the hook would only fix bullets. Prettier pads every table
  row to the widest cell whatever `printWidth` says, so a table with a long cell
  is wide in the source; nothing is `prettier-ignore`d over it. Prettier refuses
  a symlink, so the hook skips one; `CLAUDE.md` is formatted through
  `AGENTS.md`.

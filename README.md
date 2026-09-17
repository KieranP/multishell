<p align="center">
  <img src="Apps/macOS/Resources/icon-256.png" width="128" alt="Multishell icon">
</p>

<h1 align="center">Multishell</h1>

<p align="center">
  A native macOS terminal workspace for people who work in many git worktrees at once,<br>
  built for running coding agents side by side.
</p>

<p align="center">
  Projects on the left, their worktrees under them, terminal tabs and splits for the one you have selected.<br>
  Every terminal keeps running while you look at another worktree, and a dot on each tab and row says what it is doing.
</p>

<p align="center">
  <img src="docs/screenshot-light.png" width="49%" alt="Multishell in light mode: a project sidebar, a selected worktree, and a Claude Code tab split above a shell">
  <img src="docs/screenshot-dark.png" width="49%" alt="The same workspace in dark mode">
</p>

## Install

Requires macOS with Xcode 26 or later and `git` on your `PATH`.

```sh
git clone https://github.com/KieranP/multishell.git
cd multishell
sudo xcode-select -s /Applications/Xcode.app   # once, if only the command line tools are active
sudo xcodebuild -license                       # once per Xcode install, accept the agreement
sudo xcodebuild -runFirstLaunch                # once per Xcode install
make signing-identity                          # once per machine, so privacy grants survive a rebuild
make install                                   # release build into /Applications
```

`make run` builds and opens a debug copy that keeps its own state, so it sits
beside an installed one. The first build downloads libghostty, about 80 MB. Then
add a repository with the folder button at the top of the sidebar, or Cmd+O.

**Agent hooks.** For the state dots to follow an agent, it has to report through
its hooks. Open Settings > Agents: every agent on your PATH that has them gets a
row with Add, for Claude Code, Codex, Gemini CLI, Copilot CLI and OpenCode.
Where the file is the agent's own, Multishell appends one entry per event,
leaves the rest as it is, keeps a copy beside it the first time, and Remove
takes only its own entries out again. Where the agent reads a directory of hook
files, or a plugin, Multishell writes a file of its own and deletes it again.
Codex asks you to trust a new hook once, with `/hooks`. Plain shell commands
report without any of this. Until an agent's hooks are in, its dots never move
and the Agents board stays empty.

To work on it, start with [AGENTS.md](AGENTS.md), which indexes `docs/develop/`
for the build, the tests and the rules, and `docs/design/` for why things are
the way they are.

## Features

- Projects in a sidebar, every worktree under them, bare clones included.
- Tabs, splits and side-by-side columns per worktree; drag a tab to another.
- Terminals keep running while you look elsewhere.
- New worktree and branch in one step, with a terminal or agent already open.
- Removing a worktree moves it to the Trash.
- Copy or symlink `.env`, `node_modules` and the like into every new worktree.
- A state dot per tab and worktree: working, waiting, done, failed.
- Hooks for five agents; zsh and bash need no setup; anything else can call
  `multishell state`.
- An Agents board of every running agent, and a Dock badge for those waiting.
- A preferred agent one shortcut away, with flags per agent and per project.
- Notifications for tabs you are not looking at, a toggle each for state.
- Drop files from Finder onto a terminal as `@` mentions or quoted paths.
- Dirty, ahead/behind and landed badges on rows; sort, filter, rename.
- Pre and post hooks for create and delete, shareable in `.multishell.json`.
- libghostty for the terminals, JSON themes, Open in Editor, and no changes to
  your shell's rc files.

## Status

Builds and runs from source on macOS, and the permissions you grant survive a
rebuild thanks to the local certificate. There is no notarised release yet, so
build it yourself. Currently only supports macOS. Currently available in English
only.

Every line of code was written by an AI (Claude), under direction from a human
who set the requirements and reviewed the results in the running app. The design
decisions under `docs/design/` were argued out in that conversation. The
architecture, the trade-offs and what shipped were human calls.

## License

GNU Affero General Public License v3.0. See [LICENSE](LICENSE).

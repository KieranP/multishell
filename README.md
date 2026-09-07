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

Requires macOS with Xcode 26 and `git` on your `PATH`.

    git clone https://github.com/KieranP/multishell.git
    cd multishell
    sudo xcode-select -s /Applications/Xcode.app   # once, if only the command line tools are active
    make install                                    # release build into /Applications

`make run` builds and opens a debug copy that keeps its own state, so it
sits beside an installed one. The first build downloads libghostty, about
80 MB. Then add a repository with the folder button at the top of the
sidebar, or Cmd+O.

**Claude Code hooks.** For the state dots to follow Claude Code, it has to
report through its hooks. Open Settings > Agents and click "Add to
~/.claude/settings.json"; Multishell appends one entry of its own per event,
leaves the rest of the file as it is, and keeps a copy beside it the first
time. Remove takes only its own entries out again. Plain shell commands
report without this step.

To work on it, start with [DEVELOP.md](DEVELOP.md) for the build, the tests
and the rules CI enforces, and [DESIGN.md](DESIGN.md) for why things are the
way they are.

## Features

- Projects in a sidebar, every git worktree under them, terminal tabs and
  splits per worktree. Terminals keep running while you look elsewhere.
- Create a worktree and its branch in one step, where the project says.
  Removing one moves it to the Trash, so a wrong click is recoverable.
- A state dot on every tab and worktree: working, waiting for input, done,
  failed. Claude Code reports through its hooks; zsh and bash report plain
  commands with no setup; any tool can through `multishell state`, which
  also takes `--agent` to say which agent is at that pane's prompt.
- Pick a preferred agent and open it in a tab with one shortcut, or have
  every new tab start it.
- Optional notifications when a tab you are not looking at needs you.
- Drop files from Finder onto a terminal: a Claude Code tab gets them as
  `@` mentions relative to the worktree, a shell gets quoted paths. Nothing
  is run — you press Return.
- Dirty-file badges and ahead/behind counts, from a `git status` that never
  takes the index lock.
- Pre- and post-create and delete hooks per project, run through your own
  shell, with a timeout and a Stop button.
- A `.multishell.json` a repository can commit with its path, prefix, hooks
  and icon. Hooks from someone else's run only after you have said yes.
- Bare clones with worktrees beside them work as projects.
- Ghostty or SwiftTerm as the terminal, themes as plain JSON that colour the
  whole window, a font picker, Open in Editor.
- Nothing written to your shell's rc files, and state that survives an
  older or newer build.

## Status

Early and unshipped. Nothing is signed or notarised, and the release bundle
runs only on the machine that built it until the libghostty resource lookup
is fixed (see Known gaps in DEVELOP.md). Only macOS has a GUI, and only
macOS is built in CI; the core keeps to Foundation so another frontend can
use it, but nothing compiles it without one.

Every line of code in this repository was written by an AI (Claude), under
direction from a human who set the requirements, reviewed the results in the
running app, and sent it back when something was wrong. The design decisions
in DESIGN.md were argued out in that conversation, and the tests were written
to pin behaviour the human had actually exercised. It is not vibe-coded: the
architecture, the trade-offs and what shipped were human calls.

## License

GNU Affero General Public License v3.0. See [LICENSE](LICENSE).

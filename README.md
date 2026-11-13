<p align="center">
  <img src="Resources/icon-256.png" width="128" alt="Multishell icon">
</p>

<h1 align="center">Multishell</h1>

<p align="center">
  A native macOS terminal for running coding agents across many git worktrees at once.
</p>

<p align="center">
  <a href="https://github.com/KieranP/multishell/actions/workflows/ci.yml"><img src="https://github.com/KieranP/multishell/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-black?logo=apple" alt="macOS 26 or later">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-blue" alt="AGPL-3.0 license"></a>
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#features">Features</a> ·
  <a href="COMPAT.md">Compatibility</a> ·
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <a href="Screenshots/screenshot-light.png"><picture>
    <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-dark.png">
    <img src="Screenshots/small/screenshot-light.png" width="900" alt="Multishell with projects and worktrees in the sidebar, Claude Code split above a shell on the left, a second Claude Code on the right, pull request and CI marks on the worktree rows, and the Git panel listing the branch's changes">
  </picture></a>
</p>

Five agents in five worktrees usually means five terminal windows and no idea
which one is waiting on you. Multishell puts every project and worktree in one
sidebar. Pick one and its tabs, splits and agents fill the window. Switch away
and they keep running, with a dot on each tab and row saying which agents are
working, waiting on you, or done.

<!-- prettier-ignore -->
> [!NOTE]
> There is no notarised release yet. Multishell builds from source in a few
> commands; see [Install](#install).

## Why Multishell

- **Agents run in a real terminal.** Each one is its own CLI in a libghostty
  pane, so its slash commands and keys work as they do anywhere else.
- **A worktree per task.** Each agent gets its own branch, checkout, ports and
  environment files, so two of them never share a checkout or bind the same
  port.
- **You see who needs you.** Dots on every tab and row, an Agents board, a Dock
  badge and notifications. ⌘P opens on the agents waiting on you, longest first.
- **Native and local.** Swift, SwiftUI and AppKit, not Electron. No account and
  no telemetry. The app makes no network calls of its own, and agents use your
  own logins.

## Features

<table>
<tr>
<td width="45%" valign="middle">
<h3>Every worktree, and what its agents are doing</h3>
Each project has its own symbol and colour, with its worktrees and their tabs
under it. A dot says working, waiting on you, done or failed. Rows add the lines
changed, the branch's pull request and its latest CI run.
</td>
<td width="55%" align="center">
<a href="Screenshots/screenshot-sidebar-light.png"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-sidebar-dark.png">
  <img src="Screenshots/small/screenshot-sidebar-light.png" width="240" alt="The sidebar: three projects, their worktrees with state dots, line counts, pull request and CI marks, and the agent tabs of the selected worktree">
</picture></a>
</td>
</tr>
<tr>
<td width="45%" valign="middle">
<h3>Terminals that keep running</h3>
Tabs, splits and side-by-side groups per worktree, drawn by libghostty. Every
terminal keeps running while you look at another worktree, and a tab dragged to
another worktree moves without restarting.
</td>
<td width="55%" align="center">
<a href="Screenshots/screenshot-panes-light.png"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-panes-dark.png">
  <img src="Screenshots/small/screenshot-panes-light.png" width="320" alt="A tab group with Claude Code split above a shell">
</picture></a>
</td>
</tr>
<tr>
<td width="45%" valign="middle">
<h3>See what the branch changed</h3>
Modified counts from <code>HEAD</code>. Branch counts from where the branch left
its base, so an agent's commits stay listed. Every file shows the lines it
gained and lost.
</td>
<td width="55%" align="center">
<a href="Screenshots/screenshot-git-light.png"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-git-dark.png">
  <img src="Screenshots/small/screenshot-git-light.png" width="300" alt="The Git panel under Branch, listing changed files with their line counts">
</picture></a>
</td>
</tr>
<tr>
<td width="45%" valign="middle">
<h3>Review the diff beside the agents</h3>
A changed file opens as a tab beside the terminals, highlighted, unified or side
by side. Arrows step from one change to the next. An image opens too, its
committed copy beside the new one.
</td>
<td width="55%">
<a href="Screenshots/screenshot-diff-light.png"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-diff-dark.png">
  <img src="Screenshots/small/screenshot-diff-light.png" width="100%" alt="A file tab showing rate-limit.js side by side, the committed lines on the left and the new ones on the right, highlighted as JavaScript">
</picture></a>
</td>
</tr>
<tr>
<td width="45%" valign="middle">
<h3>Send review comments to an agent</h3>
Comment on any lines of a diff from its gutter. Review in the Files panel gathers
every comment, and Send writes them to one file and mentions it in the prompt of
the agent you pick, leaving Return to you. A comment follows its lines through
later edits.
</td>
<td width="55%">
<a href="Screenshots/screenshot-review-light.png"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-review-dark.png">
  <img src="Screenshots/small/screenshot-review-light.png" width="100%" alt="A side-by-side diff of rate-limit.js with two comment cards under the lines they are on, and the Review panel listing both comments to send to Claude Code">
</picture></a>
</td>
</tr>
<tr>
<td width="45%" valign="middle">
<h3>Merge once the checks pass</h3>
A row's pull request or CI mark opens its page in the side panel: each step left
before the merge and what clears it, every check, and the failing job's log.
Merge from there with GitHub's own commit message, or turn on auto-merge while
required checks still run.
</td>
<td width="55%" align="center">
<a href="Screenshots/screenshot-pr-light.png"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-pr-dark.png">
  <img src="Screenshots/small/screenshot-pr-light.png" width="48%" alt="A pull request page as steps toward its merge: no conflicts, four of four required checks passed, review approved, and a Merge button">
</picture></a>
<a href="Screenshots/screenshot-ci-light.png"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-ci-dark.png">
  <img src="Screenshots/small/screenshot-ci-light.png" width="48%" alt="A CircleCI page for a failed run, with the failing test job's log excerpt">
</picture></a>
</td>
</tr>
<tr>
<td width="45%" valign="middle">
<h3>Jump to whoever is waiting</h3>
⌘P lists the agents waiting on you first, longest wait at the top, then those
still working. Type to reach any worktree, tab or file, or start with
<code>&gt;</code> to run a menu command.
</td>
<td width="55%" align="center">
<a href="Screenshots/screenshot-switcher-light.png"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-switcher-dark.png">
  <img src="Screenshots/small/screenshot-switcher-light.png" width="100%" alt="The quick switcher on its Agents scope: two agents waiting for input, two working, one done, then those with nothing running">
</picture></a>
</td>
</tr>
<tr>
<td width="45%" valign="middle">
<h3>Every agent on one board</h3>
⇧⌘A lays every agent out by state: waiting on you, working, done or idle. Each
card names its project and worktree, the lines it changed and how long it has
been in that state.
</td>
<td width="55%">
<a href="Screenshots/screenshot-board-light.png"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="Screenshots/small/screenshot-board-dark.png">
  <img src="Screenshots/small/screenshot-board-light.png" width="100%" alt="The Agents board: columns for waiting, working, done and idle, each card naming its project, worktree, lines changed and how long it has been in that state">
</picture></a>
</td>
</tr>
</table>

### Agents

- **The agent you already use.** Claude Code, Codex, Gemini CLI, Antigravity
  CLI, Copilot CLI and OpenCode, each marked on its tab, or any command you
  name.
- **An Agents board** of every running agent, with a chip counting the subagents
  and background shells each has out.
- **A Dock badge** for the agents waiting on you, and **notifications** for tabs
  you are not looking at, toggled per state.
- **Your preferred agent** one shortcut away, with its flags set globally or per
  project.
- **Sessions resume.** Saved agent tabs pick up their session on the next
  launch.

### Worktrees

- **A branch and worktree in one step**, with a shell or agent already running
  in it. Bare clones work too.
- **Rows show ahead and behind**, and a badge once the branch has landed. Sort,
  filter and rename them.
- **`.env`, `node_modules` and the like** copied or symlinked into each new
  worktree.
- **Hooks before and after create and remove**, shared with your team in
  `.multishell.json`.
- **A block of ports per worktree**, in `MULTISHELL_PORT` and `{{port}}`, so dev
  servers in two worktrees never collide.
- **Auto Rename** asks an agent's CLI to name a worktree from its branch's
  changes. No API key, and the git branch keeps its name.
- **Removing a worktree moves it to the Trash**, or deletes it if you prefer.

### Pull requests and CI

- **Read through `gh` and `circleci`**, both optional. A row's pull request or
  CI mark opens its full page in the side panel.
- **Create Pull Request** pushes the branch after asking, then opens GitHub's
  page for it.
- **Merge from the pull request page**, with GitHub's own commit message to edit
  first, or turn auto-merge on while required checks still run.
- **Settings > (a project) > Integrations** shows each tool's version and login,
  and turns either off per project.

### Terminals and files

- **Themes colour the whole window.** Multishell's light and dark, ten editor
  ports such as Dracula, Nord and Catppuccin, or your own in JSON.
- **Drop or paste files** onto a terminal as `@` mentions or quoted paths. A
  copied image is saved to a file and pasted the same way.
- **Click in the prompt** to move the cursor there.
- **Syntax highlighting follows embedded code**, such as a Svelte file's scripts
  and styles or a Markdown fence in the language it names.
- **Arrows in a file tab** step from one change to the next.
- **Review comments** on a diff's lines go to an agent all at once.
- **Your shell rc files are never edited.**

### Keyboard

| Keys | Action                                                         |
| ---- | -------------------------------------------------------------- |
| ⌘P   | Go to any agent, worktree, tab, project or file, waiting first |
| ⇧⌘P  | Run any menu command                                           |
| ⌘N   | New worktree                                                   |
| ⌥⌘T  | New tab with your preferred agent                              |
| ⇧⌘T  | New shell tab                                                  |
| ⌘D   | Split right                                                    |
| ⇧⌘D  | Split down                                                     |
| ⌥⌘G  | Move the tab to a new group                                    |
| ⇧⌘A  | Agents board                                                   |
| ⌘F   | Find in the pane or file                                       |
| ⇧⌘O  | Open the worktree in your editor                               |

### Scripting

The `multishell` command drives the app: projects, worktrees, tabs, panes,
review comments, settings and screenshots. Multishell's own terminals have it on
their `PATH`, and Settings > Agents > Agent hooks > Install CLI links it into
`/usr/local/bin`.

```sh
multishell tabs open WORKTREE_ID --agent claude --prompt "Plan the auth fix"
multishell panes wait PANE_ID --state done
multishell state running --message "building"   # set this tab's dot from any script
```

`multishell help` lists every command. View > Enable Debug Tools shows frame
rate, CPU, memory and git timings.

## Install

You need:

- an Apple silicon Mac; Intel Macs are not supported
- macOS 26 Tahoe or later
- Xcode 26 or later (Swift 6.2), not only the command line tools
- the Zig version Ghostty pins, `zig@0.17` today
- `git` on your `PATH`

Set up the toolchain once, and again after each Xcode update. Skip
`xcode-select` if Xcode is already the active developer directory.

```sh
brew install zig@0.17                          # Scripts/build-ghostty.sh --zig-version names the version
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -license
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadComponent MetalToolchain
```

Then clone, build and install into `/Applications`:

```sh
git clone https://github.com/KieranP/multishell.git
cd multishell
make signing-identity   # once per machine, so macOS keeps your permission grants across rebuilds
make install
```

The first build compiles libghostty from the `ThirdParty/ghostty` submodule,
which takes a minute or two. Open Multishell and add a repository with the
folder button at the top of the sidebar, or ⌘O.

<details>
<summary>Debug builds and build trouble</summary>

- `make run` builds and opens a debug copy with its own state, so it can run
  beside the installed one.
- If a build fails after a pull that moved files, run `make clean` once.
- If it stops because the submodule is past its pin, run
  `git submodule update ThirdParty/ghostty`.

The full build notes are in
[Docs/develop/build/building-locally.md](Docs/develop/build/building-locally.md).

</details>

### Agent hooks

zsh, bash and fish report their state with no setup, and Claude Code and Codex
report theirs to the terminal themselves. Hooks add the subagents and background
shells those two have out. Every other agent reports only through its hooks, so
its dots stay still until you add them:

1. Open Settings > Agents > Agent hooks.
2. Click Add beside each agent. Multishell adds its entries to the agent's
   config, keeping a copy of the file the first time, or writes a file of its
   own. Remove takes out only what it added.
3. In Codex, trust the new hooks once with `/hooks`.

[COMPAT.md](COMPAT.md) lists every file Multishell touches and how far each
shell and agent goes.

## Status

- macOS 26 and later on Apple silicon. Intel Macs are not supported.
- English only.

Every line of code was written by an AI (Claude), directed by a human who set
the requirements and reviewed the results in the running app. The design
decisions under `Docs/design/` were argued out in that conversation; the
architecture, the trade-offs and what shipped were human calls.

## Contributing

Start with [AGENTS.md](AGENTS.md), which indexes `Docs/develop/` for the build,
tests and rules, and `Docs/design/` for why things are the way they are. Pull
requests are from collaborators only, as [CONTRIBUTING.md](CONTRIBUTING.md)
explains. Issues are open to anyone. Report a vulnerability through
[SECURITY.md](SECURITY.md) instead of an issue.

## License

Copyright (C) 2026 Kieran Pilkington. GNU Affero General Public License v3.0;
see [LICENSE](LICENSE). Third party notices are in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

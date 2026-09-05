# Multishell

<img src="Apps/macOS/Resources/icon-256.png" width="128" alt="Multishell icon" align="right">

A native terminal workspace for people who work in many git worktrees at
once. Projects on the left, their worktrees under them, and terminal tabs
(with splits) for whichever worktree is selected. Terminals keep running while
you look at other worktrees.

macOS now. The core is portable and CI builds it on Linux.

![Multishell with a project sidebar, a selected worktree, and split terminals](docs/screenshot.png)

## Quick start

    sudo xcode-select -s /Applications/Xcode.app   # once, if only CLT is active
    make run          # or: make install, then open it from /Applications

Add a repository with the `+` in the sidebar. Right-click a project for its
settings; Cmd+, for app settings.

Running coding agents in tabs is the point. Settings > Agent picks the
preferred agent, per project too, so Cmd+Option+T opens a tab running it, or
every new tab does with auto-start on. When Claude Code is installed the same
tab can add its hooks to `~/.claude/settings.json`. After that the tab and
sidebar dots say what each terminal is doing: grey nothing running, yellow
working, blue waiting for input, green done, red failed, with an optional
system notification for a tab you are not looking at. Plain commands in zsh
and bash report the same with no setup, and any other tool can through the
bundled `multishell state` command.

## Read next

- [DEVELOP.md](DEVELOP.md): building, testing, where things live, how to add
  a platform or an engine.
- [DESIGN.md](DESIGN.md): the decisions behind the shape of the code and the
  behaviour of the app, and why.

## Status

Early and unshipped. Nothing is signed or notarised, and only macOS has a
GUI.

## How it was written

Every line of code in this repository was written by an AI (Claude), under
direction from a human who set the requirements, reviewed the results in the
running app, and sent it back when something was wrong. The design decisions
in DESIGN.md were argued out in that conversation, and the tests were written
to pin behaviour the human had actually exercised. It is not vibe-coded: the
architecture, the trade-offs and what shipped were human calls.

## License

GNU Affero General Public License v3.0. See [LICENSE](LICENSE).

# Compatibility

Shell integration is injected into this app's terminals, and agent hooks are
written into the agent's own config on your click. An unsupported shell is still
a working terminal, and an agent without hooks still launches and resumes; it
just never updates the state indicator dot.

## Platform

| Item            | Value                           |
| --------------- | ------------------------------- |
| macOS           | 26 Tahoe and newer              |
| Other platforms | None                            |
| Build           | Xcode 26 or newer               |
| libghostty      | Ghostty's Zig, Metal toolchain  |
| git             | 2.36 or newer advised           |
| Release         | Source only, no notarised build |
| Language        | English                         |

`make build` builds for the machine it runs on, `arch=$(uname -m)` in
`Scripts/build-lib.sh`, and libghostty for it alone,
`-Dxcframework-target=native` in `Scripts/build-ghostty.sh`, so the binary is
single-architecture rather than universal. Only Apple silicon has been built and
run here; Intel is unbuilt and untested. Only Xcode 27 has been built with, the
floor of 26 resting on `xcodebuild` behaving there as it does in 27; see
[#23](https://github.com/KieranP/multishell/issues/23).

A git older than 2.36 has no `-z` for `git worktree list`, so the app reads the
newline form instead, and a worktree whose path holds a newline shows a
directory that does not exist.

## Shells

| Shell              | State dots | Click-to-move | Marks a typed agent |
| ------------------ | ---------- | ------------- | ------------------- |
| zsh                | Yes        | Yes           | Yes                 |
| bash 3.2 and newer | Yes        | Yes           | Yes                 |
| fish 4.1 and newer | Yes        | Yes           | Yes                 |
| nu                 | No         | No            | No                  |
| Others             | No         | No            | No                  |

fish writes its own prompt marks, which came in fish 4.0, and its click-to-move
came in 4.1. A fish `alias` is a function, so an agent typed through one is not
marked. nu is found and offered in the shell picker, and runs as a terminal, but
nothing is injected into it. Under nu, a dropped file whose name holds a single
quote is pasted as a line nu cannot read.

A project hook is an sh script, started from the project's shell so its startup
files set the environment: interactive and login for sh, bash, zsh, dash, ksh,
mksh and fish, interactive only for csh and tcsh, which skips `.login`. Their
functions and aliases do not reach the script, only what they export. The first
failing line stops it under every shell. A shell not in that list, nu for one,
reads no startup files, and the script runs in `/bin/sh` alone.

Your shell configuration continues to work, and no file of yours is written to.
Click-to-move puts the cursor where you click in the prompt, in terminals that
support it. A typed agent is one you ran yourself, marked from the command
rather than from its hooks. Any other shell reports only what you send it with
`multishell state`.

## Agents

| Agent            | Hooks | Waiting | Failed | Workers | `@` |
| ---------------- | ----- | ------- | ------ | ------- | --- |
| Claude Code      | Yes   | Yes     | Yes    | Yes     | Yes |
| Codex            | Yes   | Yes     | No     | Yes     | No  |
| Gemini CLI       | Yes   | Yes     | No     | Shells  | No  |
| Copilot CLI      | Yes   | Yes     | No     | Yes     | No  |
| OpenCode         | Yes   | Yes     | Yes    | Yes     | No  |
| A custom command | No    | No      | No     | No      | No  |

Waiting is a dot for an agent stopped at a permission prompt or a question,
Workers the chip counting the subagents and background shells it has out, `@` a
dropped or pasted file arriving as `@path` rather than a quoted one. Gemini has
no subagent hooks, so its chip counts only the shells it backgrounded. Codex
runs no hook until you trust it once with `/hooks`. OpenCode is given a plugin,
and is the only one that reports your answer to a permission prompt, so its
Waiting clears then rather than at the next tool call.

| Agent       | File                                      | Ours alone |
| ----------- | ----------------------------------------- | ---------- |
| Claude Code | `~/.claude/settings.json`                 | No         |
| Codex       | `~/.codex/hooks.json`                     | No         |
| Gemini CLI  | `~/.gemini/settings.json`                 | No         |
| Copilot CLI | `~/.copilot/hooks/multishell.json`        | Yes        |
| OpenCode    | `~/.config/opencode/plugin/multishell.js` | Yes        |

A file of yours is merged into, with a `.before-multishell` copy kept the first
time and Remove taking out only our own entries. One holding comments or a
trailing comma, as Gemini's may, is refused rather than rewritten; add the
entries by hand. A file of ours alone is written whole and deleted again. Where
either holds hooks an older build wrote, Settings > Agents > Hooks offers
Update, which puts this build's in their place. Nothing rewrites them unasked.

An agent is listed once its executable is on the login shell's PATH, and a saved
tab resumes it, or runs the custom line again. Typing an agent at a supported
shell's prompt marks the pane with no hooks installed, from the command alone:
`codex` marks it, `npx codex` does not.

Any of the five can be the Rename agent for Auto Rename, run once with no tool
able to change the worktree. Gemini CLI and OpenCode take no effort flag, so
they run at their own default. A custom command has no one-shot form, so with it
as the project's agent Auto Rename is off until Settings > Agents names a Rename
agent.

## Pull requests and CI

| Service  | Tool       | Version      | Read where                             |
| -------- | ---------- | ------------ | -------------------------------------- |
| GitHub   | `gh`       | No floor set | A remote `gh` says is its own          |
| CircleCI | `circleci` | 1.0 or newer | A checkout with `.circleci/config.yml` |
| Others   | None       | None         | Nowhere, the row shows no marks        |

Both tools are optional and never shipped. They are found on the login shell's
PATH and run with its environment, so `GH_TOKEN` or `CIRCLECI_CLI_TOKEN` set
there reaches them; the app never reads or stores a token. A GitHub Enterprise
host counts once `gh auth login` names it. Reads run one call per project while
the app is in front. Only the newest hundred pull requests are listed, so an
older one shows as none and the row falls back to the merged badge. Pushing for
Create Pull Request is the only write to a remote, and it asks every time.

## Reporting from anything else

Every terminal carries `MULTISHELL_SESSION`, `MULTISHELL_WORKTREE`,
`MULTISHELL_SOCKET` and `MULTISHELL_APP_PID`, plus `MULTISHELL_PORT` where its
worktree holds a port block, and the helper sits at
`~/Library/Application Support/Multishell/bin/multishell`. The states are
`running`, `attention`, `done`, `error` and `idle`:

```sh
multishell state running --message "building"
```

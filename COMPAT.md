# Compatibility

Shell integration is injected into this app's terminals, and agent hooks are
written into the agent's own config on your click. An unsupported shell is still
a working terminal, and an agent without hooks still launches and resumes; it
just never updates the state indicator dot.

## Platform

| Item            | Value                                   |
| --------------- | --------------------------------------- |
| macOS           | 14 Sonoma and newer, Apple silicon      |
| Other platforms | None                                    |
| Build           | Xcode 27, or 26 for the libraries alone |
| git             | 2.36 or newer                           |
| Release         | Source only, no notarised build         |
| Language        | English                                 |

## Shells

| Shell              | State dots | Click-to-move | Marks a typed agent |
| ------------------ | ---------- | ------------- | ------------------- |
| zsh                | Yes        | Yes           | Yes                 |
| bash 3.2 and newer | Yes        | Yes           | Yes                 |
| fish               | No         | No            | No                  |
| nu                 | No         | No            | No                  |
| Others             | No         | No            | No                  |

fish and nu are found and offered in the shell picker, and run as terminals, but
nothing is injected into them.

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
| Gemini CLI       | Yes   | Yes     | No     | No      | No  |
| Copilot CLI      | Yes   | Yes     | No     | Yes     | No  |
| OpenCode         | Yes   | Yes     | Yes    | Yes     | No  |
| A custom command | No    | No      | No     | No      | No  |

Waiting is a dot for an agent stopped at a permission prompt, Workers the chip
counting the subagents it has out, `@` a dropped file arriving as `@path` rather
than a quoted one. Codex runs no hook until you trust it once with `/hooks`.
OpenCode is given a plugin, and is the only one that reports your answer, so its
Waiting clears then rather than at the next tool call.

| Agent       | File                                      | Ours alone |
| ----------- | ----------------------------------------- | ---------- |
| Claude Code | `~/.claude/settings.json`                 | No         |
| Codex       | `~/.codex/hooks.json`                     | No         |
| Gemini CLI  | `~/.gemini/settings.json`                 | No         |
| Copilot CLI | `~/.copilot/hooks/multishell.json`        | Yes        |
| OpenCode    | `~/.config/opencode/plugin/multishell.js` | Yes        |

A file of yours is merged into, with a `.before-multishell` copy kept the first
time and Remove taking out only our own entries. One holding comments, as
Gemini's may, is refused rather than rewritten; add the entries by hand. A file
of ours alone is written whole and deleted again.

An agent is listed once its executable is on the login shell's PATH, and a saved
tab resumes it, or runs the custom line again. Typing an agent at a supported
shell's prompt marks the pane with no hooks installed, from the command alone:
`codex` marks it, `npx codex` does not.

## Reporting from anything else

Every terminal carries `MULTISHELL_SESSION`, `MULTISHELL_WORKTREE`,
`MULTISHELL_SOCKET` and `MULTISHELL_APP_PID`, and the helper sits at
`~/Library/Application Support/Multishell/bin/multishell`. The states are
`running`, `attention`, `done`, `error` and `idle`:

```sh
multishell state running --message "building"
```

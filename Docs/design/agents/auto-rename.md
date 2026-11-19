# Auto Rename

Auto Rename, which runs an agent's CLI once to name a worktree. Newest at the
bottom.

- **Auto Rename runs an agent's own CLI once, not an API.** No key to store, and
  the user's own sign-in and plan pay. Cost: an agent's start-up on every run.
- **It sets the display name only**, as Rename does. The branch is what a
  remote, a pull request and every git command track.
- **Rename model and effort are lists in the catalogue, not text**, or a typo
  reaches the CLI and fails mid-run. Read on 2026-10-24: Claude's and Gemini's
  aliases, the models `codex debug models` lists as visible with each one's
  efforts, Copilot's `help config` list, and for OpenCode the newest of three
  providers', its own list being whichever providers the user set up.
  Antigravity came later, the models its 1.4.8 binary names. Cost: each month's
  releases are copied in by hand.
- **Effort is per model where the CLI says so.** Codex's gpt-5.5 takes no max or
  ultra, so an agent's default model is offered only what every listed model
  takes. Copilot names one set for all, so each model is offered all of it,
  unchecked per model.
- **A stored model the catalogue has since dropped runs as the agent's
  default**, and stays listed in its picker rather than showing blank.
- **Gemini CLI and OpenCode take no effort flag**, Gemini's thinking budget
  being a setting and OpenCode's a model's variant.
- **A custom command cannot be the Rename agent**: it has no one-shot form the
  app knows.
- **No tool of the agent's can touch the worktree.** Claude: `--tools ""`,
  `--strict-mcp-config` with no config, and user settings only, `-p` skipping
  the trust prompt a repository's own hooks wait behind. Codex: the read-only
  sandbox, and its MCP servers emptied, the sandbox holding only its shell.
  Gemini: plan mode. Copilot: shell and write denied and its built-in MCP
  servers off; a user's own MCP server is left to the prompt mode, which runs a
  tool needing a yes only under `--allow-all-tools`. OpenCode: every permission
  denied through `OPENCODE_CONFIG_CONTENT`, and a repository's own config and
  plugins off through `OPENCODE_DISABLE_PROJECT_CONFIG`, a cloned repository
  being anyone's. Hence `--standalone`: `run` otherwise hands the prompt to the
  background service, another process, which never sees this run's environment.
  Read from each one's `--help` on 2026-10-24, and OpenCode's variable from its
  binary. Cost: unchecked against the running CLIs, as a run reads the user's
  own account.
- **Costs left there**: Gemini still starts the user's MCP servers, plan mode
  holding back their tools but not their launch; a repository's own `.gemini`
  settings wait on Gemini's trust, which the run never gives. Whether Copilot
  runs a repository's hooks in prompt mode is unread. Antigravity runs in plan
  mode, which makes no edit, but no flag of its takes a tool away
  (agents/reports-and-hooks.md).
- **Claude and Codex keep no session of it** (`--no-session-persistence`,
  `--ephemeral`); Gemini, Copilot and OpenCode show no such flag in their help,
  so the run is in their history.
- **It starts in the worktree with `PWD` saying so.** The login shell's
  environment was captured in the home directory, and a CLI exec'd with no shell
  between reads its project from what it is handed.
- **The run's own hooks report nowhere** (`MULTISHELL_SOCKET` is `/dev/null`).
  With no pane the helper falls back to the app's socket, and its report, naming
  only a directory, would move the worktree's dot and post a Done.
- **It reads commits and the index against the Branch view's base**: unstaged
  and untracked work is often half done or a stray. Merge commits are left out
  of the subjects, which say what came in rather than what the branch does. At
  most 50 subjects, a diffstat of 60 files and 20,000 bytes of diff, a small
  part of any listed model's window. A NUL is taken out, the prompt going as one
  C-string argument that would end there. The stat and the patch come from one
  `diff`, git computing a large branch's once. Cost: git's whole diff is read
  before the cut, so a branch adding a large generated text file holds it in
  memory for the run.
- **Whether there is anything to name is read from what the status read and the
  branch scan already hold**, so a menu costs no git. The scan, not the
  worktree's listed `HEAD`: a commit moves a ref the scan reads at once, and the
  listing waits.
- **A bare repository's row is never offered**: its empty index reads as a
  branch deleting every file.
- **Before the login shell has answered, a run says the agent is still being
  looked for**, not that it is missing.
- **Escapes are stripped as ECMA-48's whole forms** from the reply, `ESC c` and
  `ESC % G` among them, a CLI's colour taking more than `0-9;`. A quote between
  two letters is an apostrophe, so `'Fix user's avatar'` loses only its outer
  quotes. Marks inside the name stay, `__init__` being a name.
- **A reply about what no longer stands names nothing**: a branch changed under
  the run, or the user named the row or opened its field, theirs outranking the
  agent's. The agent is told the branch from the run's own read of `HEAD`, not
  the listing's, which lags a checkout made in a pane.
- **The agent's words are their end, 300 characters cut at a line**: standard
  error then standard output, as a Node warning on one would hide an error on
  the other, and Codex prints its banner and the prompt to standard error and
  the error last. Its styling is taken out, a login shell's `FORCE_COLOR`
  reaching the Node CLIs.
- **Removing the worktree or quitting stops its run**: the agent otherwise spent
  the user's quota for up to 90 seconds in a directory gone, or with no timer
  left after a quit to end it.
- **A failure stays on the row as a warning until clicked, and posts a banner
  behind the Failed toggle**, the user's pick on 2026-10-24 over an alert, which
  could land up to 90 seconds after the click on whatever was being typed. A
  failure known at the click gets no banner, the row the user is looking at
  answering it. Cost: the banner shares the worktree's key with a directory
  report's banner, so either takes the other's back as it goes.
- **VoiceOver says the row's Auto Rename failed, and the reason as its hint**,
  up to 300 characters of an agent's words being too many for every visit.
- **Ninety seconds, then it stops**: a long diff on a slow day takes tens of
  seconds, and past that nobody is watching the row. Cost: the bound and a
  removal's stop cover the agent, not the git reads before it, which take no
  stopper; a hung volume holds the row's spinner until git returns.

## Reviewed and left as is

- **Antigravity's `--continue` after an Auto Rename run** (round 17): it picks
  the latest conversation in the workspace, by the research of 1.4.x, so tabs in
  other worktrees keep their own, but a rename run in the same worktree may be
  the latest. The cost already recorded for Gemini, Copilot and OpenCode, whose
  runs also stay in their history.

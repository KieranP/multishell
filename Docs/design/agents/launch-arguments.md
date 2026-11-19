# Flags, placeholders and the starting task

What an agent is started with: its flags, the placeholders in them and the New
Worktree sheet's task. Newest at the bottom.

- **Flags are stored per agent id**, not as one line for whichever agent is
  chosen: flags are written for a particular CLI, and another will reject them.
  Cost: switching agent and back is two lines to fill in.
- **The line is split into words here**, not passed to the shell as text, so a
  branch with a space in it stays one argument. Quotes and backslashes group the
  way a shell reads them, so a regex keeps its escapes; checked against zsh by
  random lines. A quote left open takes the rest of the line, there being nobody
  to ask.
- **The placeholder list is drawn nowhere in the app**, the custom command's row
  and the starting port naming one as an example: a reference page in a tooltip
  is what the documentation is for. Cost: unlike the hook variables, a new case
  reaches the docs by hand.
- **An unknown placeholder is left as typed**, so the mistake shows in the tab
  rather than an argument going missing. So is `{{port}}` in a worktree with no
  port block (worktrees/ports.md).
- **One pass over what was typed**, so a token inside a value is text: a branch
  named after another placeholder used to be expanded again.
- **The branch placeholder on a detached worktree is the short SHA, never
  blank**: an empty value reads as an error the agent reports, where a wrong
  name does not.
- **Flags are appended on resume too.** A tab that comes back continuing a
  session is the same tab, and the flags said how that tab is meant to run.
- **A flag line is not shell text**, so a branch name someone else pushed cannot
  run anything. Checked against real sh, zsh, bash and tcsh with a substitution,
  backticks and a semicolon in the branch: each arrived as the one argument
  meant and none ran. The values are not only branches, which git keeps tame,
  but a worktree name the user typed and paths that are whatever the directories
  are called.
- **Each word is quoted the one way every shell reads alike**, a `!` and a
  backslash outside the quotes: the login shell running the line may be tcsh or
  fish, which read either inside single quotes (terminals/sessions.md). Cost: a
  home shortcut or a glob in a flag line is literal, so a path there means a
  placeholder or the custom command.
- **The custom command and the custom editor are shell text**, so a value
  written into them is shell text too: quoted where it landed, a `$(…)` in a
  branch ran anyway inside the user's own quotes, which close or ignore ours.
- **So each placeholder there reads a variable** (`MULTISHELL_BRANCH` and the
  rest), set by `env` around the login shell so no shell parses a value on the
  way. The read is quoted in one spelling that is one word in sh, zsh, bash,
  dash, tcsh and fish, each checked with hostile values.
- **Finding the user's quotes needs the login shell's name**: fish alone reads
  `\'` and `\\` inside single quotes, so `'it\'s {{task}}'` is one quoted string
  there and a quote left open in the rest.
- **A wrong guess about the quoting costs a split word, never a command**: a
  placeholder inside `$(…)` inside double quotes reads unquoted, and bash splits
  it, but nothing in a value is ever run.
- **Neither flags field carries prompt text.** A greyed example in an empty
  field reads as what the agent is already started with. The custom command's
  own prompt stays: there it cannot be mistaken for a running command, an empty
  field meaning no agent starts at all.
- **The project override is a line, not a table**: it overrides whatever agent
  the project runs. Blank is the override to no flags (settings.md).
- **Flags are not in the repository's file**: a flag is an argument to a
  program, and that file is trusted unasked only for what is drawn; what runs
  from it, its hooks, waits on a yes (settings.md).
- **The New Worktree sheet's task reaches the agent as an argument after its
  flags**, the way each CLI's help says an interactive session takes a first
  prompt: the prompt operand for Claude and Codex, `--prompt-interactive` for
  Gemini and Antigravity, `--interactive` for Copilot, `--prompt` for OpenCode.
  Read from each one's `--help` on 2026-10-09, Antigravity's on adding it on
  2026-10-29.
- **An operand goes behind `--` and an option takes the task after `=`**, so a
  task opening with a dash is never read as a flag. Cost: unchecked against the
  running CLIs, as starting one would read the user's own config.
- **A one-word operand task carries a trailing space**: Claude's CLI reads a
  lone word behind `--` as a subcommand, so `claude -- doctor` ran doctor
  (2.1.295), and no subcommand name ends in a space. Cost: Codex's one-word task
  carries the space too.
- **A line break in a task becomes a space.** tcsh refuses one inside quotes and
  inside a quoted variable read alike, answering "Unmatched '" and starting
  nothing.
- **A custom command's `{{task}}` is empty where none was typed**, so the token
  never reaches the shell.
- **The flag line has no task placeholder**: a catalogue agent is handed the
  task already, and a flag naming it would pass it twice.
- **A task goes with the tab's first launch only**, and is runtime state, so a
  restored tab resumes without asking again.

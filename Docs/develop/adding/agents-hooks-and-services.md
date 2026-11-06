# Agents, hooks and services

What adding an agent or editor, a pull request host or CI provider, a hook stage
or an agent's hooks needs beyond the code itself.

- **An agent or editor.** A row in its catalogue; detection and the dropdowns
  follow. An agent's row names its mark; its colour is a `ui.agent_marks` key in
  every built-in theme, empty where the project's mark has no colour of its own.
- **A pull request host or CI provider.** A case in `ServiceIntegration` with
  its tool's name, a conformance to `PullRequestHost` or `CIProvider` in
  MultishellServices under a folder of its own in `SCM/` or `CI/`, reading
  through `ServiceToolRunner`, and an arm in `ServiceConnections`. The
  Integrations page's label, help and install words follow, which the compiler
  asks for, and its place in `ServiceIntegration.settingsPageOrder`, which a
  test asks for. A second host also needs a way to choose between hosts:
  `pullRequestHost(for:)` takes the first turned on and installed, in `allCases`
  order, before either is asked whether the repository is its own.
- **An agent's one-shot run**, for Auto Rename: the flags that run one prompt
  with no tool able to write, how the prompt goes, its model and effort flags,
  and its models with each one's efforts, in `AgentCatalogue+OneShots`.
  AgentOneShotTests pins each row's arguments; nothing checks them against the
  CLI's own help.
- **Removing an agent adds its id to `AgentCatalogue.retiredIDs`**, or a state
  file naming it raises an install alert for it at every run:
  WorkspaceRetiredAgentsTests.
- **A new mark** needs a case in the drawn list and in the resource lookup, plus
  a single-path `.svg` of that name in the app's marks folder, in the square
  `AgentMarkShapeTests` holds them all to, with absolute commands only:
  SVGPathParserTests holds the parser to refusing the rest.
- **The monogram needs none of that** and is what an agent ships with until
  someone draws one. Give the agent a row in COMPAT.md's table, the only place a
  user reads what the app does with it.
- **A hook stage.** A case in the hook stage, an arm in each of the script and
  directory lookups, the call from the coordinator in order, an error title
  saying whether the operation happened, an editor on the Hooks page, and an
  operation stage with its text. A stage that runs after the git operation also
  goes in `isAfterOperation`, which nothing forces; left out, a removal reads
  its failure as a veto.
- **A way a worktree stage can fail.** A failure type naming what is still on
  disk, an error title, and an arm in the removal describer saying whether the
  worktree is still there, which decides whether the row is restored or
  refreshed. Nothing forces the arm: without it the failure falls to the Trash's
  default and the row comes back.
- **A list of files a new worktree is given.** A case in the placement with the
  settings field it reads, an operation stage with its titles and Cancel help,
  and an editor on the Hooks page.
- **If a repository may ship that list**, it also needs a field on the shared
  settings, a line in the layering, and the two places trust and containment are
  spelled out (`trustCoveredFields`, `confined(to:)`), since it names paths on
  the reader's disk, and its name in the trust question in `trustCoveredNames`,
  at the same position, as a `shared-settings.` key in the libraries' catalogue.
- **An agent's hooks.** An integration in the hook catalogue's list, naming the
  file, the events, what each says the session is doing, which of two events
  standing for one thing is silent, which two are a subagent's start and end,
  which is the prompt that starts a turn, and which is its session starting.
- **An event's timeout goes below five seconds where the agent caps it**, as
  Codex does its two exit events at three, or it warns at every start.
- **Every agent with events needs the turn-starting one.** Most agents fire no
  hook on an interrupt, and the workers it killed send no stop, so the next
  prompt alone clears them, dropping every worker no Stop saw out and no list
  names as background work.
- **A payload names a worker by id and type**, or in that agent's own spelling,
  which needs a line in the payload reader. A start or end naming no worker
  still counts as one, taking an unnamed place.
- **Whether the agent takes a turn when work it left out ends goes on the
  integration too**, beside whether a worker is a conversation of its own and
  which listed kinds wake it. All default to no, so nothing forces them: a
  resuming agent left at the default pays Done at its last worker out and again
  at the woken turn's Stop (design/agents/background-work.md). Four more are
  read only in Claude's format, so another agent needs a reader of its own
  before it can say yes to any: whether its transcript shows a notice still
  queued at a Stop or a question a permission prompt stands for, whether a file
  beside it names each worker's parent, and whether a tool call's result names
  the background work it launched or stopped.
- **An agent whose payload names no event** needs a case of the payload
  spelling, which puts `--event` on its hook line, and a payload reader of its
  own. Left at the default, every payload reads as none and the hook reports
  nothing, exiting 0 all the same.
- **An agent keeping named sets of hooks in a file of the user's** takes the
  named-set format: our set's name is the section every merge, install check and
  refusal reads, and its `enabled` is kept through Update.
- **An agent whose Stop does not list the shells it backgrounded names a shell
  marker on the integration**, text only such a shell's command line holds.
  Nothing forces it either: without one a pane waiting on the shell goes Done
  early (design/agents/background-work.md).
- **An agent reporting through a plugin** names a worker through the helper's
  subagent flags, the worker that launched it included, starts a turn through
  its new-turn flag, and at a Stop that resumes lists what is still out through
  its resumes and out flags. It also needs a catalogue row, the Agents page's
  Agent hooks part offering hooks for agents detection found.
- **An agent with no hooks at all needs a plugin**, as one already has. A file
  that is ours alone is written whole and deleted to remove.
- **A variable a hook receives.** A case in the hook variables, which both
  builds the environment and draws the Hooks page's table, named by the
  placeholder meaning the same, so the two cannot be spelled apart.
- **A placeholder an agent's flags may use.** A case with its value and the
  variable a custom command reads it from. The settings rows name one as an
  example rather than the list, and no page in the repository lists them yet, so
  nothing tells a user the new one exists.

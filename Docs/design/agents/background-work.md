# Background shells, wake-ups and nested workers

Work an agent leaves running past its turn, the Done it is owed, Claude's list
of what is out and the workers launched under others. Newest at the bottom.

- **A shell the agent backgrounded is a worker too**, the user's rule for
  subagents applied to the other thing a turn leaves running: a pane waiting on
  a build it started showed Done, then Idle once looked at.
- **No hook or notification type says a background shell ended**, so its end is
  its exit: the pid goes on the roster and the pid poll takes it off, paying the
  Done as the last worker out would.
- **Where a Stop does not list them, the helper finds them for Gemini**: no tool
  call is in flight at a Stop, so any tool shell still alive under the agent is
  one it backgrounded. It lists the agent's children and keeps those whose
  command line holds the agent's shell marker.
- **The marker, not "any child"**: MCP servers and the agent's other helpers are
  children for the whole session and would hold every Done forever.
- **Gemini's marker is the wrapper every shell-tool command runs in**, its
  `/gemini-shell-` temporary directory in the argv, which its `!` shell mode and
  MCP servers lack. It is how the agent happens to start a shell, not a
  contract: if it changes, nothing matches and a pane goes Done early, as
  before, rather than Working for good.
- **One place per pid however many Stops name it**, since a turn woken by the
  shell's output stops again with the shell still listed until the poll sees it
  go.
- **An unnamed worker's end never takes a shell's place.** A shell is never a
  hook's to end, and one taken that way would be off the roster and unpolled.
- **Cost: a pid reused before the poll looks holds the Done** until the new
  process goes, the poll seeing only that the number is alive.
- **An agent that takes another turn when work it left out ends is paid its Done
  by that turn's Stop, never by the last worker out.** Paying it at the exit
  announced Done, then Working, then Done again seconds later, with two banners.
- **Claude and Copilot always do**, the work's end reaching the model as a
  message; OpenCode for every child, a cancelled one too; Gemini only where
  steering is on and a finished shell injects or notifies, read from its
  settings at each Done in Gemini's order, system defaults first and a project's
  own only in a folder Gemini trusts, by its own rule.
- **Codex does not**: a child's answer is recorded with `trigger_turn: false`,
  so its last worker out pays.
- **Under an empty `HOME` Gemini's settings are read from Node's temporary
  directory**, where Gemini reads them. Read from anywhere else, steering went
  unseen and a Done came at the shell's exit and again at the turn's Stop.
- **The Stop says so**, the integration being the only place an agent is known,
  and the entry keeps it beside the Done it owes.
- **A cancelled worker wakes nobody, so its end says so**, and last out it pays
  the Done unless a turn is underway: one an earlier end woke, or one the agent
  is already reporting from. That turn's Stop pays it instead, or a cancel
  mid-turn announced a Done the turn's own Stop announced again.
- **No timer pays it either**, the user's rule being that only the agent's own
  Stop with nothing out is Done. A fifteen-second fallback was tried: 15 of 266
  woken turns in real transcripts took longer to report, up to 58 seconds, so
  the timer announced a Done mid-turn and 13 of them announced another at the
  Stop.
- **Cost: a wake-up that never comes leaves the pane Working** until the next
  prompt, the agent exiting or the user's clear, as an interrupt does. In the
  same transcripts 128 of 129 background launches woke the agent, and the agent
  itself stopped the last mid-turn.
- **A resuming agent's Stop with no list sweeps for gone processes first**: a
  shell's exit reaches the agent at once and the poll up to two seconds later,
  and a Stop held for a shell already gone would leave nothing to pay the Done.
- **A worker heard after a resuming agent's Stop was out at it**, its start
  landing late, since the agent launches workers only inside a turn. The Done
  that Stop announced goes back with the banner, and the turn the worker's end
  wakes pays it: paid at the last one out, a late start meant three banners.
- **Claude's Stop lists what is still out**, its `background_tasks`, and the
  roster is made that list: a worker it leaves out has ended whatever its hooks
  said, and one it names is out though its start has not landed.
- **Because a hook cannot be relied on for it.** Nothing documents whether a
  subagent's end is awaited before the parent hears of it, or whether TaskStop
  fires one at all; a Stop held for a worker already gone left the pane Working
  until the next prompt.
- **Reading the transcript for which workers ended was tried first** and dropped
  for the list, a hook field Claude documents for telling a finished session
  from one waiting on its work. The transcript is still read at a Stop, but only
  for what the list cannot say: a notice queued and not delivered.
- **Its shells come in the list under Claude's own id for them**, so no process
  is walked for Claude, and the next Stop's list is a shell's end, Claude waking
  at each exit.
- **A task can finish too late for its notice to join the turn and too early for
  the list**, its notice queued as the model writes its last words: the Stop
  lists it no longer and Claude starts a turn over it milliseconds after. In
  real transcripts 87 of 241 woken turns began under two seconds after the Stop,
  each a second Done.
- **So Claude's Stop reads its own transcript for a notice queued since the last
  Stop and not yet delivered**, taken off the queue or handed to the model, and
  one there holds the Done as a worker out would. Replayed over every Stop in
  those transcripts it caught all 80 queued before the Stop began, and the list
  held the rest; every Stop it held was followed by a turn.
- **Not a contract, so a changed format finds nothing**, which is the second
  Done again rather than Working for good.
- **Only the kinds whose end is announced to the model count**: subagents,
  shells, workflows, MCP tasks and cloud sessions, each read from Claude's
  binary to end in a task notice to the main agent. The Monitor tool is a shell
  and counts with them, holding the pane Working while it runs.
- **Left out, because counted they would hold the pane Working for good**: an
  MCP or websocket monitor, which includes the ambient artifact watchers that
  never end; a teammate, listed while idle and announcing its idle rather than
  its end; memory dreaming and the auto-mode scan, which end unannounced. A kind
  Claude adds later is left out too: an early Done is the lesser harm.
- **A subagent's own shells go with it**: Claude kills them as it exits and
  sends the main agent what they would have told it, so the main agent is woken
  for what its Stop listed.
- **The list's ids are the hooks' `agent_id`.** Claude 2.1.283 names a
  subagent's task by the id it launches it under and its transcript
  `agent-<agent_id>.jsonl`, read from the binary.
- **OpenCode's plugin sends its own list at the parent's Done**, the children it
  saw start and not end, which outranks what a missed event left behind. Only
  that session's own, its children's children among them: two sessions in one
  plugin listed each other's (`aSessionsDoneListsOnlyItsOwnChildrenAsOut`).
  Under the service every session reports to the one worktree roster, so there a
  Done lists every session's
  (`underTheServiceADoneListsEverySessionsChildrenAsOut`).
- **And one report at a time, each once the helper before has exited**, with a
  two-second bound on a helper that never does. Started together they landed in
  either order, and a cancelled child's end landing after the Done that left it
  out put it back on the roster for good.
- **A quiet Working already queued drops its twin**, a session's own or a
  worker's that starts nothing and asks nothing, when only quiet Workings stand
  between them: each helper that hangs holds the queue two seconds, and a burst
  of tool calls queued minutes of reports, a parent's and a child's in turn
  among them (`aParentsAndChildsToolCallsInTurnQueueOneWorkingEach`). A prompt
  between them keeps both, or the reply's Working was taken for the tool call's
  and the prompt never cleared
  (`aWorkingQueuedBeforeAPromptDoesNotSwallowTheReplysWorking`). An app gone or
  with a full backlog costs nothing here, macOS refusing the connect at once.
- **OpenCode's woken turn runs no prompt hook**: a child's end reaches the
  parent as a synthetic message, so the plugin reports that turn's start as a
  plain Working. Read as a new turn it emptied the roster of the children still
  out. A prompt naming no session starts no turn either, for the same reason.
- **Shells and subagents are counted apart** wherever workers are counted, a
  shell not being a subagent to anyone reading the label.
- **A sweep takes every dead agent before any dead shell.** An agent gone with
  its shell takes the shell with it; checked in a set's order, the shell was
  sometimes first and announced a Done for a dead agent.
- **The close guard and the quit alert count an agent's Working, not the
  shell's.** When they counted any running command, a plain `make` asked to be
  confirmed. An agent typed with no hooks installed counts, the command having
  named it (`closingATabRunningAPlainCommandAsksNothing`,
  `anAgentTypedAtThePromptWithNoHooksCountsAsWorking`).
- **Debug Info covers the panes as the board does, through the same predicate**,
  so under it too no pane is in view, no Done is seen and no banner held back.
  An agent's pid is still polled only for the board, Debug Info showing no
  agents (agents/board-and-pane-rows.md).
- **A worker another worker launched is listed under it**, as Claude's own list
  draws a skill's workers under the skill. Flat, a review fanning out eight
  angles read as nine unrelated workers, each called `general-purpose`.
- **No hook payload names a worker's parent**, checked for Claude 2.1.292 and
  Codex 0.160.0 against the schemas in their binaries. Copilot's end names the
  conversation it ran under, too late to list it there.
- **Claude writes it beside the transcript instead**:
  `<session>/subagents/agent-<id>.meta.json` holds `parentAgentId`, absent for
  the agent's own, and the `name` a skill runs under or the task's
  `description`, which is what its own list shows. The helper reads it on each
  event inside a worker and sends the parent, name and description with it.
- **Not at the worker's start**: Claude runs that hook before it writes the
  file. In a real review the file came 30 to 65 ms after the worker's first
  transcript line and 5 to 11 seconds before its first tool call, so a worker
  sits at the top until then.
- **Not a contract, so a changed format lists every foreground worker at the
  top**, named by its kind, as before; nothing about the state moves.
- **The id goes into a path, so only letters, digits, `-` and `_` are read**,
  and a parent naming anything else is no parent.
- **OpenCode's plugin names a child's parent where that parent is itself a
  child**, the session's `parentID`, read at its creation or its lookup. Codex
  records its own in the child's rollout file, but whether a hook names that
  file inside a worker is unread, so its workers stay flat.
- **A worker whose parent is no longer out is drawn at the top**, as is one in a
  loop of workers naming each other, so nothing out goes unlisted.
- **The count still counts every worker**, nested or not, the chip saying how
  much is out rather than how many the agent launched itself.
- **A screen reader hears each nested worker as under its parent**, by name, the
  label being one string rather than rows it could step through.
- **A Stop's list keeps every worker under one it names**: Claude lists only
  background work, its filter skipping a task marked foreground, so a foreground
  worker launched by a background one was read as ended, and a prompt it had up
  went with it. Read from Claude 2.1.292's binary.
- **The list follows Claude Code's own panel**, read from 2.1.292's binary: a
  worker under the worker whose `parentAgentId` it names, siblings in the order
  they started, the name it was launched under (else its kind) and what it was
  launched to do. Unlike that panel, every level is drawn, a list opened on
  demand having no viewed agent to follow.
- **A worker's SubagentStop is not its end.** Claude fires one at every turn end
  of a worker's, and a worker waiting on its own workers or a backgrounded shell
  ends its turn to wait. Read as its end, a parent waiting on five went at once,
  its five drawn at the top, and each of them waiting on a shell went too,
  leaving one or two of six.
- **Claude's list decides background work.** Every Stop and SubagentStop lists
  the session's work in flight, the worker's context sharing the agent's
  registry, and a background worker lists itself until its run returns, its last
  stop included. So a worker its own stop lists is paused, and one an earlier
  list named ends when a later list leaves it out. Foreground work is never
  listed, so a list ends none of it.
- **A worker that ends with work it launched still out stays**, drawn as out as
  Claude draws it, and goes with the last of that work. One that ended is
  remembered, so a child whose parent is named only after the parent ended is
  still drawn under it.
- **What a worker launches is put under it at the launch**: the result Claude
  hands PostToolUse names the shell (`backgroundTaskId`) or the async worker
  (`agentId`, with its name and description). Without it a parent pausing 10 ms
  before its children's first tool call held none of them, and a shell had no
  owner at all.
- **A killed or failed worker is drawn failed for 30 seconds**, Claude's own
  linger, then swept. A failed row holds no Working, so the Done is not held for
  it.
- **A TaskStop names what it killed**: its result carries `task_id`, and Claude
  stops everything under that task with it, so the task and all it held turn
  failed. A stopped parent's child and both their shells went in one captured
  run. A prompt one of them had up goes too: Claude closes the dialog, and the
  pane otherwise stayed Waiting.
- **Esc on a subagent sends nothing**, nor does a stop from Claude's task list,
  so it is read from the list. A worker that finishes always sends its own stop,
  listing itself, before it leaves, so a launched worker that leaves the list
  with no stop of its own since its last report was killed or crashed. One
  killed while paused sent its stop first and goes unmarked.
- **A worker's own stop never puts it back**: each hook is its own process, and
  in a captured run the main agent's prompt from a hand-back was logged before
  the stop of the worker that handed back. A list that overtakes that stop reads
  the worker as killed; the stop arriving after it ends the worker, rather than
  reviving it into a Working nothing would end.
- **Only a worker a launch result named is judged so**: OpenCode lists its
  workers too and sends no such stop, and a shell never sends one. One Ctrl+B
  sent to the background has no launch result, so its kill goes unmarked.
- **A paused worker leaves the list while its own work runs.** Claude ends its
  run as completed, noting it may resume, and starts it again when that work
  reports; the work launched under it keeps it, as Claude's panel keeps a
  finished agent whose work is alive. When the last of that work ends, which is
  what wakes it, it waits one list for its start; in a captured run that start
  came in the same second.
- **A stop that leaves its own background worker out is also marked failed**, as
  the binary's abort path reads; no captured run has sent one.
- **A new turn keeps background work.** The hand-back reaches the agent as a
  prompt, which keeps only what the last Stop saw out; a worker launched since
  went with it and came back at the top on the next list. Listed or launched
  work is background work, which no interrupt ends. Esc on the agent sends no
  hook and ends none of its background work; without this rule, the first prompt
  after it dropped every worker and shell, no Stop having seen them out.
- **Five captured Claude runs replay every payload through Claude's hook
  integration and the roster**, in the `claudesCaptured` tests of
  `SessionStatesTests+ClaudeCapture.swift` (develop/tests/conventions.md).
- **A start for a worker whose `meta.json` exists is a resume**, Claude starting
  a worker again under its id after a SendMessage, not a second worker under one
  place.

## Reviewed and left as is

- **`--subagent-wakes` with nothing in the repository sending `false`** (round
  1, 2026-10-28): it is an option of the helper's `state` command, which a
  user's own script or plugin may send, and fields are only ever added. The rule
  that a cancelled worker's end says so stands for any reporter that knows it.

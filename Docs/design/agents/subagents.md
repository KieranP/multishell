# Subagents and the worker roster

How each agent's subagents are counted on a pane, what they owe and what they
hold, and the chip that shows them. Newest at the bottom.

- **A main-loop stop is not the turn ending.** A subagent launched in the
  background outlives it and its tool calls keep reporting, so the pane went
  Done, Working, Done again, once per wave, each with a banner.
- **So the subagent start and end are asked for too**: a stop with any
  outstanding is held as Working, and the last worker to end pays the Done the
  agent was owed.
- **What is outstanding is a roster the app keeps**, a hook being a fresh
  process with nothing to remember. An agent that reports no workers never
  enters that arm, and its stop means Done outright.
- **What takes a worker off the roster**: Idle, Failed, the process going, the
  shell's own command returning, the user's clear or a Stop's list that leaves
  it out.
- **A worker's start and end carry Working and are bookkeeping, not news**: they
  leave a Waiting or a Failed where it is, or a background worker ending while a
  prompt was up withdrew the banner with the prompt still on screen.
- **Such a tick reports nothing back to the model.** It carries no message, so
  letting it through would replace the prompt's words on the card and repost the
  banner under the same key, replacing the one there.
- **A tool call inside a worker is work, as the main thread's is.** The prompt a
  worker's tool raised names the worker, and that worker's next call clears it,
  not the main thread moving.
- **Subagents are a roster by id.** The counting events name the worker, and so
  does every hook that fires inside it, so a start or a first tool call puts one
  on and its end takes it off.
- **The count is how many workers those places stand for**, which exceeds the
  places only where an agent names two workers alike.
- **The roster holds 64 places, and one more shared by every worker past them**,
  which keeps their ids and counts, so the count stays true, a tool call is not
  a new worker and a stray end takes nothing. Dropping the oldest paid a Done
  while it still ran. Cost: a shell past 64 is dropped, its pid having nowhere
  to go in a shared place, and so is a worker past 1,024 ids.
- **Each carries its kind and when it started**, stamped by the model's one
  clock as a state is.
- **Not the tool it is in, though the payload says**: shown, it changed with
  every call and made the list flash; carried, it re-rendered the sidebar per
  call.
- **No task description from a worker's own hooks**: no agent's payloads carry
  one. Claude's comes from a file beside its transcript or from the result of
  the call that launched it, both in agents/background-work.md.
- **The wire field is an object naming the worker.** The older count field is
  still read, each increment as an unnamed worker, because the hooks' helper
  link is shared between builds and points at whichever launched last.
- **For the same reason a start and an end also write the count beside the
  object**, for an older app; a tool call writes none, or each would put another
  unnamed worker on that app's roster.
- **An interrupt fires no hook, Codex's aside, and the workers it killed send no
  stop**, so an interrupted fan-out left its chip standing. Codex's `Interrupt`
  reports Idle, which clears the pane and its roster.
- **What says the last turn is over is the prompt that starts the next**, so
  that event clears what the turn owed or asked, before its own Working lands.
- **It keeps the workers a held Stop saw out**, which are background ones, a
  foreground worker always ending before its agent's Stop. Emptied at the
  prompt, a Copilot or Codex pane went Done while one still ran, their Stops
  listing nothing, and Copilot's woke for a second.
- **A Stop vouches only for a worker heard from since the last one**, by a hook
  or by the Stop finding it running: a worker whose end was lost falls silent,
  and kept on every Stop's word it held a Codex or Copilot pane Working for
  good.
- **It drops any other**, which an interrupt could have killed without a word.
  Cost: the chip stands from the interrupt to the next prompt, however long; the
  pid poll cannot help, the agent being alive at its prompt.
- **A kept worker that was killed goes by what the agent says next**: Claude's
  Stop lists it no longer, OpenCode's Done leaves it out, Codex's `Interrupt`
  clears everything. Cost: where nothing says so, as for a Copilot worker
  cancelled from its task list if that fires no stop, it holds the pane Working
  until the pane is cleared or the agent exits.
- **A worker out is work, the user's rule**: a pane showing Done, or nothing,
  shows Working while any is out.
- **What the worker's report stood over is remembered once**, and the last
  worker out puts it back, so a Done is paid and announced at the end and the
  banner fires once.
- **Provided the worker's start was seen**: one first seen at a tool call after
  the Done was announced lifts it and announces it again, the app having no way
  to tell a late worker from a new one.
- **A Failed comes back unannounced and as old as it was**, having been
  announced when it happened. Only a worker's prompt displaces it; mere work
  leaves it standing.
- **The agent's own Working takes the dot back for itself**, so the last worker
  out leaves it, and gives up that claim even where another thread's prompt
  holds the dot, or a Done would fire mid-turn.
- **Its own prompt claims a Working put over nothing, but not a Done it owes.**
- **A Done the agent's stop owes is its own kind of displaced.** Hooks are
  separate processes over a socket, so a main-thread event can land after the
  stop it preceded, and the agent's own Working would have thrown the owed Done
  away.
- **A held stop leaves a failure alone either way**, or a failure would be paid
  back as a Done; over one still standing the stop is not even news.
- **A Waiting is cleared by the thread that raised it and by nothing less.** A
  roster of raisers holds each thread asking, and a thread's next tool call
  takes its own prompt off.
- **Otherwise, with two workers out, the second's tool call withdrew the first's
  prompt** from the dot and the banner with the prompt still on screen.
- **A worker ending with its prompt still up takes the prompt with it**, the
  user having denied it, or nothing the agent did afterwards could.
- **The agent's stop over a worker's prompt is held**, the Done owed, and the
  prompt stays until that worker moves or ends. A failure, a new turn and the
  user's clear still move it.
- **Cost: a prompt whose thread never calls a tool again and never ends holds
  the dot until the turn ends**, which nothing documented does.
- **The raiser is the roster place the report touched, not the id on the wire**,
  because an older helper names no worker and every unnamed one asked under the
  same empty id, so one end answered them all.
- **An unnamed worker's end takes the last that is asking before the last that
  is not**, the only way an interchangeable worker can answer its own prompt.
- **With no unnamed place left it takes the oldest of any kind**: one worker did
  end, and a place left over holds the Done for the rest of the turn.
- **A start or end naming nobody is read as an unnamed worker**, not the agent's
  own report, and its tool call takes the last unnamed place rather than minting
  one, which would leave the chip counting tool calls.
- **Per agent, from what each says to a hook.** One spells the two events as the
  first does, behind its own feature flag.
- **One runs a subagent as a conversation of its own**, firing its own prompt,
  tool calls and Stop under its own conversation id and no worker id. Read as
  the agent's, its Stop put the pane at Done mid-turn, once per worker.
- **So the pane keeps its own conversation's id**, taken from the first report,
  a session start or a Stop, and a report under any other id is a worker keyed
  by it. Its end names that same id as the worker's, so the two meet.
- **A worker's end also names the conversation it ran under**, so a pane that
  heard a worker first, opened or launched mid-subagent, takes that one as its
  own there rather than counting the parent as a worker until its Stop.
- **Its Stop is told apart without that memory**: the transcript it names is
  filed under its parent's id and never names its own. The helper drops it, the
  end following at once.
- **Not by the transcript's directory**, though that is where the id sits today:
  another agent names the file instead, and under that layout the directory rule
  would have dropped every one of the pane's own Stops. A path naming the id
  anywhere is the pane's, so a changed layout costs a Done mid-turn, never every
  Done.
- **Its start is not asked for**: it arrives in the agent's other spelling,
  which names no id, and one keyed by name alone would never be ended. The
  worker goes on at its own first event instead, so the chip shows no kind.
- **A new conversation of the pane's that sends no session start reads as a
  worker until its Stop**, whose transcript says it is the pane's; its place
  goes then. Cost: Working all that turn, which it was anyway.
- **A session start over Working or Waiting moves nothing**: one agent's prompt
  mode sends it after the first prompt, and its idle cleared Working until the
  first tool call. Over anything else it clears, as a fresh session should.
- **A `/clear` after an interrupted turn still clears**: Claude and Gemini fire
  their session end, which is not held, before the start, as Claude does for
  `/resume`. Read from claude 2.1.286 and gemini 0.46.0, not watched; Copilot's
  is unread.
- **The shell's own Working is not one of those**: it stands from the moment the
  user types the agent's name, so a start held off by it left every agent
  launched from a prompt Working until its first turn ended.
- **A start repeated under one id counts its starts and takes as many ends**, or
  a Done is paid while the second is still working; the chip counts workers, not
  places, so it says two where the list holds one.
- **Nothing says which of them a later report came from**, so neither a tool
  call nor an end under a shared place answers a prompt raised there while
  another worker is on it. Cost: a prompt the asking worker answered stays until
  its sibling's next report.
- **A duplicate start, which no agent documents, would hold the place until the
  turn ends.** That agent's built-in worker emits neither event.
- **One agent names a subagent to its telemetry and never to a hook**, so its
  rows show none.
- **One runs a subagent as a child session**, its plugin reading the child's
  creation as a start, its run starting and tool calls as work, and its run
  ending, however it ends, as the end. A child's end is not the pane's Done.
- **A parent's run starting says Working only where no prompt already has**, so
  a turn the prompt hook never saw still shows, and ends in a Done.
- **An ended child's id is kept, marked rather than deleted**, so a second end
  or a late permission of its own is not read as the parent's; only its next run
  puts it back. A move away drops its session's children outright, as they now
  run elsewhere.
- **A child the plugin never saw created is asked about**: a task resumed by its
  id reuses its session and publishes no creation, so its first message read as
  the parent's prompt. One lookup is in flight per id, and a hook waits at most
  a second for its turn in the session's queue, which an earlier event's
  unsettled lookup can hold each time; an answer after the bound still puts the
  child back.
- **Ended ids are kept in their own capped list, oldest first**, capped on that
  list rather than on the map: gated on the map, a child running and ending over
  and over grew the list without bound.
- **One place per child there**, so those cycles neither grow the list nor push
  other children out.
- **The chip is the count behind a branch glyph in the Working colour**, on a
  pane's row and its board card while that pane has a worker out. With none out
  it counts the failed workers still drawn, in the Failed colour; with neither
  it is gone, as an empty chip would be one more badge on every row.
- **Not on the worktree row**, which was tried: the row already carries four
  badges, and the pane rows say which pane the swarm is in.
- **A report naming only a directory keeps its workers under the worktree's
  key**, moving the worktree's dot and showing on no chip, there being no pane
  to hang one on.
- **Hovering the chip lists them, name and time**, in a popover that ticks while
  up; nothing else grows, so a large fan-out costs the sidebar no rows and the
  board no height.
- **Chosen over rows under the tab**, with which a fan-out would push the next
  project off screen, and over cards of their own, which broke one card per
  pane.
- **Cost: the list is never on screen unless the pointer is on the chip**, and a
  screen reader gets it as the chip's label rather than as rows.

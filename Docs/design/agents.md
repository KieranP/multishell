# Agents

The inbound channel, each agent's hooks, the board that shows them and the
command line's requests on the same socket. Newest at the bottom.

- **The inbound channel is a Unix socket and a small helper.** Not a URL scheme,
  which would activate the app dozens of times a minute; not netcat, for the
  quoting, a stable protocol and one place for each agent's mapping.
- **Fields are only ever added.** A report naming an unknown session is dropped,
  not matched by directory.
- **Every string off the channel is bounded**, since any process of the user's
  can write a line. An id, agent or command word past 128 characters is dropped,
  not cut, as a cut one could name something else; a worker's id past it counts
  as an unnamed worker. A path past 1024 bytes is dropped. A worker's kind and
  name are cut to 64, its description to 200 and the message to 500, all display
  only. A Stop names at most 64 shells. A duration outside zero to a week is
  dropped, being a writer's number, not a clock's.
- **One naming only a directory marks the deepest worktree containing it**, so
  an agent started in a subfolder says that folder, and a nested worktree is the
  one meant.
- **Each worktree's resolved path is kept, missing or not**: resolved per
  report, a mount answering only after its timeout stalled the window each time.
  Foundation leaves a missing path's links unresolved, so one kept then is
  resolved again once a status read, the directory check or the next report's
  look off the main actor sees the directory.
- **The pid a report names is what the app polls** to clear a Working the agent
  never took back.
- **The app hands each session its own pid**, or the helper's walk past the
  shells reaches the app itself, whose pid never goes. A report naming the app's
  pid, from an older helper, is taken as naming none.
- **A report carries only what the app cannot see**: state, pid, message, a
  duration so a fast command posts no banner, and the agent, since a pane's
  agent is usually started by hand.
- **A report moves a dot, raises a notification and decides how a dropped file
  is written.** It opens no tab, runs no command and types nothing at a prompt;
  a command-line request may do all three (below).
- **Shell reports never go in the background**, or a fast command's finished
  overtakes its started (terminals.md).
- **Four agents share one hook line and one parser**, each running a command at
  every lifecycle event with the same three fields. What differs is the file,
  the event names and how the file spells a hook. A fifth, Antigravity, runs the
  same line naming its event, its payload having its own reader.
- **The app knows no agent by name anywhere else.**
- **Only the last month of each agent's releases is supported.** A feature every
  release of that month has is relied on with no branch for older ones. This
  limits the agents' releases, not the helper's own protocol.
- **Each is asked in its own spelling**: one has a permission request where
  another has a notification, one has both and is asked for both, and one is
  asked in the spelling whose payload names its event.
- **One counts its timeout in milliseconds**, where the obvious number would
  kill the helper before it reached the socket.
- **One clamps its two exit events' hooks to three seconds** and warns at every
  start where one asks for more, so those two are written as three.
- **One reads a directory of hook files rather than a settings file**, so its
  file is ours alone: written whole, deleted to remove, no copy kept.
- **A file of ours alone is rewritten only by Update**, as a settings file is.
  Rewriting at launch one an older build wrote took a hand edit with it, the
  file carrying no sign of which it was. Cost: a fix in that file reaches only
  those who press Update.
- **A settings file of the user's holding any hook of ours counts as
  installed**, so one an older build wrote, short an event added since, reads as
  needing Update rather than not installed.
- **The first builds' `claude-hook` line is still known as ours**: the helper
  exits 0 on it and reports nothing until Update replaces it. An unknown command
  exits 2, which Claude takes as blocking a tool, a prompt or a stop, and Remove
  and Update take out only a line known as ours
  (`theLineTheFirstBuildsWroteIsStillOursToReplace`,
  `theFirstBuildsClaudeHookLineExitsZeroInSilenceAndReportsNothing`).
- **A file of the user's is never rewritten unasked**, since the write sorts its
  keys and re-indents it. The row offers Update instead, which swaps ours for
  this build's and keeps a hook of theirs inside our group.
- **One reports to no command at all**, only to a plugin seeing a session's run
  end, so it gets a plugin calling the helper as any script would.
- **That one alone says a permission was answered**, allowed or denied, so its
  pane alone clears Waiting on the answer rather than at the next tool call.
- **Its permission hook is deliberately not used**: `permission.evaluate` runs
  for every check, answered or not, and would repeat a prompt the event bus
  already reports.
- **Cost of the plugin**: JavaScript in the user's agent, so it spawns, unrefs
  and swallows everything, and it is the one integration whose contract we do
  not control from a payload.
- **The plugin's source is a Swift string, not a `Resources` script** as the
  shell integration's are: the helper writes it, and from `Contents/Helpers` the
  resource bundle in `Contents/Resources` is out of its reach.
- **Four events are narrowed**, "the agent raised a notification" not being "the
  agent is waiting".
- **One raises a notification when a background shell finishes** as much as when
  it needs an answer, so ours asks for the two types that are questions.
- **One has no notification, only a permission request that fires before it
  decides whether anyone need answer**, so under a full-auto mode every tool
  call would post a banner. It counts as waiting only in a mode that stops for
  the user, and an unknown mode is taken to stop.
- **Another's request is the same shape and narrowed the same way**, its
  classifier mode being one more that answers without the user.
- **That agent's notification carries many types on one event**, most of which
  announce rather than ask, including an idle prompt that landed on top of the
  Done the same turn had just reported.
- **So the announcing types are named and everything else counts as waiting**, a
  deny list, so a question added later raises a dot instead of falling silently
  out.
- **The list is read from the agent's own**, plus two types it sends outside it.
  A type saying the task will not go on without the user, such as a usage limit
  reset waiting for Return, asks.
- **Sorted from the payload's own type, not the event's matcher**: a matcher is
  written into the settings file, so it would reach only installs made after the
  build that adds it, and an agent old enough to send no type would match none.
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
- **One agent's request is asked for beside its notification, not instead**: the
  notification is slower and is dropped if the user answers first, so alone a
  quick prompt never moved the dot and a slow one moved it late.
- **So a prompt reports twice**: the request moves the dot with no banner; the
  notification raises the banner and carries the wording, the request having no
  message.
- **That delay is the agent's own rule for when a prompt is worth an
  interruption.** The general rule: move a dot silently where another report
  about the same thing will do the talking.
- **Nothing reports the answer**, so the dot stays until the next tool call or
  the end of the turn: an approved call taking minutes holds it that long.
- **The denial event is not the missing half**, whatever its name suggests: it
  fires only for a call the auto mode's classifier turned down, and a person
  refusing at the prompt fires nothing.
- **The other agents have nothing of the kind**: one request is already the
  immediate one, one notification has a single type, and one fires before its
  own rules run with a payload that never says the mode.
- **Claude words its question to the user as a permission request**: the
  question tool goes through the permission dialog, whose notification says
  "Claude needs your permission" and names no tool. The helper reads the
  transcript's last tool call and, where it is an unanswered `AskUserQuestion`,
  marks the report a question. The app words that as needing input from its
  catalogue, the helper having none; an older app shows the agent's message.
  Only Claude's transcript is read, though Copilot sends the same type.
- **One error event is deliberately left**: it carries a recoverable flag, and a
  red dot for something the agent recovers from is worse than none.
- **The hook line runs the helper rather than exec'ing it, and exits zero
  whatever became of it.** Two agents block a tool call on a non-zero hook exit,
  so under exec a helper killed by Gatekeeper would stop the agent working.
- **Cost: one short-lived shell per event**, the pid coming from walking past
  shells either way.
- **The line sets no variable, so it parses in fish as well as sh**: which shell
  an agent runs its hooks through is not ours to choose.
- **A settings file that is a symlink is written through, not over.** An atomic
  write would leave a regular file where a dotfiles repo's link was.
- **The copy kept sits beside the link**, not in the repo it points into, where
  the user's next status would have to explain it.
- **Nothing under an event is written over.** Absent means an empty list to add
  ours to; a string, an object or a shape a later version takes is the user's
  and could not be put back, so Add refuses and names the event.
- **Remove takes back what Add put in and nothing else**, inside a group as well
  as between them: a group holding one of ours beside one of theirs was written
  by hand, so ours are stripped and the group stands. So too a group that is
  also a bare hook, whichever half is ours.
- **Dropping at group granularity read as Remove working**, the file even
  shrinking, while an audit hook someone had added to our entry went with it.
- **Numbers are written back as the user spelled them.** Parsed to doubles, a
  short decimal came back long and a round one came back integral.
- **Each literal is carried as a string behind a marker**, drawn once per
  process so a string of the user's cannot be taken for a number on the way out.
- **Only a literal the grammar allows is marked**, the rest left for the parser
  to refuse. The bytes are decoded strictly first: a lossy decode wrote a
  replacement character over a byte of the user's.
- **A settings file that will not read back as plain JSON is refused**, not
  parsed loosely: one agent's takes comments and keeps them when it writes the
  file itself, and a re-serialisation here would take them out.
- **Cost: those users add the entries by hand**, so the alert names the file and
  points at the JSON.
- **One agent will run no hook it has not been told to trust**, so the row says
  installing is not the end of it; nothing here can trust a hook for the user.
- **No agent is recommended** or has anything of its own outside the catalogue.
  An install prompt for one agent was an endorsement in a workspace built to run
  whichever agent the user already chose.
- **Cost: a machine with none installed gets an empty picker and no help filling
  it.**
- **An agent dropped from the catalogue is forgotten on load**
  (state-and-store.md).
- **The Agents board is a roster, not a queue.** Every open pane has a card,
  moving between columns as its state moves, so nothing is hidden by having been
  looked at.
- **A card goes when its pane closes**, and in one other case: an agent whose
  process has gone leaves a plain shell behind, which the filter hides.
- **Failed waits with Waiting, not in Done**: a failure wants the user, which is
  what that column means, and Done keeps one meaning.
- **They part on a dead process**: a question was a claim about that process and
  goes with it; a failure outlives the thing that failed and stays.
- **The filter is the one control and decides membership alone.** A shell it
  lets in lands where its state says, the injected integration already reporting
  a command started and finished, so a build is Working and a failed test suite
  waits.
- **No duration floor, though the banner policy has one**: a banner interrupts,
  a card does not, and the sidebar dot already goes green for a trivial command.
- **The filter lives on the model, not the view**, because the Dock badge counts
  what the Waiting column shows and must read the same flag. Cost: off again
  after a relaunch.
- **While the board is up, nothing acting on "the tab in front" acts**: closing
  would end a shell nobody can see, opening would make a tab that appears only
  once the board is left. One predicate answers for all of them.
- **Showing the board also means no pane is shown**, or the selected worktree's
  Done states would clear as it opens and their cards reach Idle without passing
  through Done.
- **An agent's pid is polled only while the board is up**, one sweep as it
  opens: nowhere else shows a quit agent, and always watching would leave a
  timer running for as long as any agent had ever reported.
- **The shell's word that its foreground command returned drops the agent at
  that prompt too**, the agent having been that command, since the Dock badge is
  read with the board closed where no pid is polled.
- **Four columns are always drawn, empty or not.** Labelled columns say what the
  board is for, where a page in their place says only that it is not working.
- **An empty board adds one line saying what would put something on it**, since
  without a report nothing can know an agent is at a prompt. Not gated on hooks
  being installed: one agent's being in place says nothing about the agent at
  the prompt.
- **The board is built once and held until anything the build read changes**: it
  reads every pane's title, state, note and workers and every worktree's status,
  so a title change in one pane rebuilt every card on every render. The build
  runs under observation tracking rather than a hand-kept list of inputs, which
  would drift from the sidebar the first time someone added one. Cost: any store
  write drops it, a focus change included.
- **Newest first everywhere**, so an arriving card pushes the rest down a place
  and nothing else about a card moves on its own.
- **Columns share the room down to a floor and the board scrolls past it**, a
  partial column at the edge saying there is more.
- **No end arrows**, which the tab strip needs because a tab scrolled out of
  sight is one you forget exists; the board has four fixed columns.
- **No line of output on a card**: the core can read a pane's text since
  `panes read`, but each read takes the engine's renderer lock on the main
  thread, a cost paid per card every time a line would refresh.
- **Flags are stored per agent id**, not as one line for whichever agent is
  chosen: flags are written for a particular CLI, and another will reject them.
- **Cost: switching agent and back is two lines to fill in**, and the settings
  row shows only the chosen agent's.
- **The line is split into words here**, not passed to the shell as text, so a
  branch with a space in it stays one argument.
- **Quotes and backslashes group the way a shell reads them**, down to a
  backslash inside double quotes guarding only the few characters it does, so a
  regex keeps its escapes. Checked against zsh by random lines.
- **A quote left open takes the rest of the line**, there being nobody to ask,
  and an opener carrying nothing passes no argument rather than an empty one.
- **The placeholders are one list**, and only the custom command's row and the
  starting port's name one, as an example: a reference page in a tooltip is what
  the documentation is for.
- **So unlike the hook variables the list is drawn nowhere**, and a new case
  reaches the docs by hand.
- **An unknown placeholder is left as typed**, so the mistake shows in the tab
  rather than an argument going missing.
- **So is `{{port}}` in a worktree with no port block**, and Settings >
  Worktrees names it in a caption (worktrees.md).
- **One pass over what was typed**, so a token inside a value is text: a branch
  named after another placeholder used to be expanded again.
- **The branch placeholder on a detached worktree is the short SHA, never
  blank**: an empty value reads as an error the agent reports, where a wrong
  name does not.
- **Flags are appended on resume too.** A tab that comes back continuing a
  session is the same tab, and the flags said how that tab is meant to run.
- **A flag line is not shell text.** Each word is split and quoted, so a branch
  name someone else pushed cannot run anything: substitutions, backticks and
  semicolons all arrive as literal characters.
- **Checked against real sh, zsh, bash and tcsh** with a substitution, backticks
  and a semicolon in the branch: each arrived as the one argument meant and none
  ran.
- **The values are not only branches**, which git keeps tame, but a worktree
  name the user typed and paths that are whatever the directories are called.
- **Each word is quoted the one way every shell reads alike**, a `!` and a
  backslash outside the quotes: the login shell running the line may be tcsh or
  fish, which read either inside single quotes (terminals.md).
- **The same quoting makes a home shortcut or a glob in a flag line literal**,
  which is the cost: a path there means a placeholder or the custom command,
  which is raw shell by definition.
- **The custom command and the custom editor are shell text**, so a value
  written into them is shell text too: quoted where it landed, a `$(…)` in a
  branch ran anyway inside the user's own quotes, which close or ignore ours.
- **So each placeholder there reads a variable** (`MULTISHELL_BRANCH` and the
  rest, named as the hook variables are where one means the same), set by `env`
  around the login shell so no shell parses a value on the way.
- **The read is quoted for where the placeholder sits**, in one spelling that is
  one word in sh, zsh, bash, dash, tcsh and fish, each checked with hostile
  values.
- **Finding the user's quotes needs the login shell's name**: fish alone reads
  `\'` and `\\` inside single quotes, so `'it\'s {{task}}'` is one quoted string
  there and a quote left open in the rest.
- **A wrong guess about the quoting costs a split word, never a command**: a
  placeholder inside `$(…)` inside double quotes reads unquoted, and bash splits
  it, but nothing in a value is ever run.
- **Neither flags field carries prompt text.** A greyed example in an empty
  field reads as what the agent is already started with, and the field's whole
  job is to say what is passed.
- **The custom command's own prompt stays**: there a greyed example cannot be
  mistaken for a running command, an empty field meaning no agent starts at all.
- **The project override is a line, not a table**: it overrides whatever agent
  the project runs. Blank is the override to no flags (settings.md).
- **Flags are not in the repository's file**: a flag is an argument to a
  program, and that file is trusted unasked only for what is drawn; what runs
  from it, its hooks, waits on a yes (settings.md).
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
  the call that launched it, both below.
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
- **Where the pieces disagree, the pane's dot is what they agree on**: a report
  for a worker not on the roster puts it on, an end for one never seen takes
  nothing, and the roster clears with everything else.
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
- **The selected worktree lists its panes in the sidebar**, one row per pane,
  not per tab, so a glance says which pane is working and which has a swarm
  without reading the strip.
- **A tab was the row first**, and a split's second pane, with its own agent and
  dot, was nowhere.
- **A split's panes carry a split glyph and their position**, since a renamed
  tab names every pane alike and two plain shells both read as the shell.
- **The worktree row drops its terminal count**, the rows under it being the
  count.
- **The active tab's focused pane is bold, one per worktree**: with two groups
  two tabs are on screen, and two bold rows read as two selections.
- **A click shows another and hands it the keyboard**, as a board card does.
- **Only the selected worktree's**, so one set takes room at a time and a
  project with many panes does not become that many rows. Cost: selecting a
  worktree shifts every row under it.
- **Each pane row's height is what the sidebar's block height counts off**, or
  the drop indicator lands in the wrong half.
- **An agent is drawn as its own mark** wherever a pane says what it is running:
  the five the app draws, two letters for everything else, the terminal glyph
  for a shell.
- **A mark is recognised without reading**, which is all a slot at the smallest
  UI font can carry; letters at that size are pairs a glance has to tell apart
  on shape alone.
- **A stock symbol per agent is a mapping nobody can learn**: nothing about a
  generic glyph says which agent it is.
- **One `.svg` per mark, not hundreds of lines of path calls**, each a single
  path in the square the test holds them to: the art is data, a mark can be
  replaced without touching Swift, and a diff of a new mark is one line.
- **Only absolute move, line, curve and close commands are read**, which is all
  those files hold; anything else is refused rather than drawn half.
- **A file that will not parse is left out of the table**, so the mark draws
  nothing; the test walks every file, turning that into a failing test rather
  than an empty tab.
- **All five are traced from the projects' own icon sets and icons**, the shape
  being what is recognised.
- **One outline is sampled from the icon itself**, radii from its centroid
  through a smooth curve: regular lobes were tried by hand, and neither is that
  irregular shape.
- **Two marks run to the edges of their square** rather than sitting inset,
  those icons being the mark itself with no padding of their own.
- **One prompt is cut out of its blob rather than drawn over it**, so one fill
  colour carries both; the cut is made when the file is generated.
- **Two are alike at tab size and told apart by their tint**, which is the
  projects' doing and not something to fix by drawing either one wrong.
- **A mark black or white upstream is drawn in the text around it**; the rest
  carry the project's own colour as the built-in themes' `ui.agent_marks`, which
  a user theme may change or empty.
- **Cost: a mark redrawn upstream is wrong here until someone notices**, a trace
  is only as good as its source, and the programs that traced these are not in
  the tree. The `.svg` is the artefact and the thing to edit.
- **A mark is drawn, so it is said**: a tab and a pane row name their agent
  after their title, and drop it where the title is the agent's name.
- **The fallback is letters rather than nothing**, one from each of the first
  two words, so a command the user typed and an id a newer build stored both
  draw something.
- **A typed agent is known from the command, not only from its hooks.** A pane's
  mark comes from the hook report that names it, then the command the shell said
  it was starting, then the tab's own id.
- **The middle one is why typing an agent's name in a plain shell marks the
  pane** with no hooks installed: the injected integration carries the program's
  name, first word and no path, matched against each agent's executable.
- **That answer is held only while the command runs.** Any report from the shell
  itself that names no command takes it back: the prompt coming back, the shell
  exiting, or the next command.
- **Keyed on the report having no agent, not on its state**: an agent's own
  hooks report running all through a turn and name themselves, and clearing on
  those would drop the shell's answer the moment it started working.
- **Which reports are the shell's is a field it sets**, not a guess: the helper
  is documented for the user's own scripts, and one run inside a turn reports
  with no agent and no command; read as the shell's, it would blank the mark.
- **Matched on the executable alone**, so a wrapper invocation is nobody: the
  word is the command. A leading assignment, `command`, `env` or `exec` is
  stepped over first.
- **Only a word naming an agent's executable goes on the shell's own line**, the
  shell matching it against the list it was generated with, so no word needs a
  JSON escape. Cost: a script of the user's named after an agent marks its pane
  as that agent.
- **The state dot badges the mark instead of taking the slot.** A tab has one
  leading slot, which used to hold either the dot or the tab's kind.
- **The dot sits on the mark's lower-right corner, ringed in what is behind
  it**, so a row says what is running and how it is doing at once, covering the
  mark's edge rather than the middle that carries the shape.
- **Covering part of the mark is the right trade**: a state is read down a whole
  strip, a mark only where the eye already is, and an idle pane draws the mark
  whole.
- **The sizes were set by rendering the shapes from tab size up and looking**,
  which threw out a hand-drawn mark that read as an animal at tab size.
- **A mark that only works blown up is no mark**, and the box cannot grow: the
  tab floor holds only what a tab already draws at the smallest UI font and a
  short title.
- **The tab's dot keeps its click**, which clears a stale Working state, and the
  whole glyph is now that target.
- **A split tab loses its split symbol where an agent is at the prompt**: one
  slot draws one thing, and which agent is working matters more from across a
  strip than which tabs hold two panes. The row still says split to a screen
  reader.
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
- **The prompt starting a turn keeps them**, as it keeps every worker a held
  Stop saw out.
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
  agents (debug-tools.md).
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
  `SessionStatesTests+ClaudeCapture.swift` (develop/tests.md).
- **A start for a worker whose `meta.json` exists is a resume**, Claude starting
  a worker again under its id after a SendMessage, not a second worker under one
  place.
- **A failed tool call is Working, as a finished one is**: the agent reads the
  error and carries on. Claude and Copilot send it as its own event, their
  PostToolUse firing on success only; Codex's PostToolUse and Gemini's AfterTool
  fire on a failure too. Unasked, an approved call that failed left the dot at
  Waiting until the next call.
- **Claude's MCP request is asked for beside its notification**, as its
  permission request is: Elicitation moves the dot at once and silently, the
  `elicitation_dialog` notification six seconds later raises the banner. No mode
  answers one, so it is not narrowed by mode.
- **ElicitationResult is the answer a permission never sends**, so an MCP
  request's Waiting clears when the user answers, not at the next tool call.
- **Cost: Claude waits for its Elicitation hooks before it shows the dialog**,
  so a wedged app delays the question by up to the hook's timeout. Read from
  Claude 2.1.292's binary.
- **The other agents have no MCP request event**: Codex handles one with no
  hook, Gemini's MCP client cannot receive one, and Copilot's arrives as the
  notification already asked for, with no answer event. Read from Codex 0.160.0,
  Gemini 0.46.0 and Copilot 1.0.91.
- **The New Worktree sheet's task reaches the agent as an argument after its
  flags**, the way each CLI's help says an interactive session takes a first
  prompt: the prompt operand for Claude and Codex, `--prompt-interactive` for
  Gemini, `--interactive` for Copilot, `--prompt` for OpenCode. Read from each
  one's `--help` on 2026-10-09.
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
- **A custom command reads the task as `{{task}}`**, from `MULTISHELL_TASK` as
  the placeholders read theirs, empty where none was typed so the token never
  reaches the shell.
- **The flag line has no task placeholder**: a catalogue agent is handed the
  task already, and a flag naming it would pass it twice.
- **A task goes with the tab's first launch only**, and is runtime state, so a
  restored tab resumes without asking again.
- **The command line's requests share the reports' socket**, one JSON line in
  and one answer back on the same connection. A second socket would need its own
  claim, and its name would eat into the `sun_path` budget a worktree's variant
  already spends (develop/state-on-disk.md).
- **A request and a report tell themselves apart by shape**: a request has
  `request` beside `v` and no `state`, so neither parses as the other. A request
  this app does not know gets no answer, which the helper reads as an app older
  than itself; so does one whose `v` is newer than the app's, since a case of
  the same name may mean something else by then.
- **Requests open tabs, run commands, type at a prompt, create and remove
  worktrees, and change settings, in both builds.** Reversed 2026-10-10, so a
  user can script their start-up over many projects and an agent can drive a
  debug build. Cost: any process of the user's that can connect to the socket
  can run a command in a pane, outside any sandbox an agent runs in that lets it
  reach a Unix socket. The socket stays mode 0600, which is all that separates
  users.
- **Typing is keystrokes, not a paste**: libghostty brackets a paste for a
  prompt that asked, and zsh holds a bracketed newline in the line rather than
  running it, so the text goes as an input method's commit and Return as its own
  key. `panes paste` is the paste, for text meant to wait at the prompt.
- **A request goes to the helper's own build's socket, never the pane's
  `MULTISHELL_SOCKET`**, so a debug helper run in a release app's tab drives the
  debug app. Reports keep the pane's, being about that pane.
  `MULTISHELL_CONTROL_SOCKET` names another, for the tests, and only in a debug
  build, so one left in a release shell's environment cannot turn its helper on
  another app.
- **A request is done as the menu item or click it stands for**, through the
  same model call, so a setting written from the command line repaints and
  refreshes as the Settings window's does. An alert the action raises comes back
  as the refusal, in the app's language, and is taken down, so it does not stand
  in the app after the command line has had its words.
- **An alert is the request's only where it was made in the request's own
  task**, which the alert records as it is made: one waiting on git or a hook
  has the app going on around it, and a guess from what was on screen after took
  a click's alert for its reason and took it down.
- **What goes back up is what the request's alert covered when it went up**, not
  what stood when the request began: a click or the model may have raised or
  taken one down in between, and an alert the user dismissed meanwhile is not
  brought back. One a click or an answered request raised between two of the
  request's alerts goes back up instead, or the request's finish wiped it
  unanswered
  (`aUsersAlertRaisedBetweenTwoOfARequestsAlertsComesBackWhenItFinishes`).
- **A request whose alert another request covered still answers with it**, and
  the later one then takes down to what the earlier one's covered: answered
  plainly, the first left its own alert to come back up after it had replied,
  with nothing left to take it down. A task a request starts inherits its id, so
  an alert is filed only while that request is still being answered.
- **A request answers with its newest alert even once it is gone from the
  screen**, replaced by a click's or dismissed. Answered plainly, a create whose
  git failed exited 0
  (`aRequestWhoseAlertAClickReplacedAnswersWithItAndLeavesTheClicksUp`). Only an
  alert going up in its own request's task is filed, so one a finishing request
  puts back is not taken for a new one: two requests finishing out of order
  brought the second's answered alert back over the user's
  (`twoRequestsAlertsFinishedInReverseOrderAnswerEachAndTheUsersComesBack`).
- **An agent named for a new tab or worktree is checked before anything opens.**
  The launch would otherwise open a plain shell in its place and raise its alert
  once a run, so a script would read a shell as the agent and a retry would
  answer success.
- **Nothing a request does waits on a dialog.** A close, removal or quit over a
  working agent is refused unless `--force`, and otherwise done without asking:
  a dialog nobody at the command line sees would stand until someone clicks.
- **A removal forces the branch delete only with `--force-delete-branch`**, as
  git's `branch -D`. The alert's Force Deletion is taken down with the alert,
  and the worktree is gone by then, so a second request could not reach the
  branch (`aForcedBranchDeletionDeletesABranchGitWouldKeepAndRaisesNoAlert`).
  Reversed 2026-10-11 from `--force` doing both: getting past a working agent
  then also lost an unmerged branch's commits
  (`aForcePastAWorkingAgentStillLeavesABranchGitWouldKeep`).
- **A helper that hangs up cancels its request**, so Ctrl-C on `worktrees add`
  stops the pre-create hook or git as the sheet's Cancel does. The helper shuts
  its writing half after the request, so EOF says nothing; the reply polls for
  POLLHUP, which macOS sets only once both halves are shut, every 250 ms until
  it is sent. A cancelled task stops nothing else: nothing else a request awaits
  checks for it.
- **The app answers in data and the helper words it** (translation.md): ids and
  JSON on success, a typed refusal otherwise.
- **Whatever a command prints is JSON**, indented and sorted as the app's
  answers are, so a script reads every command one way; a stream, `debug log` or
  `debug samples --follow`, is one object a line. `panes read` and `debug log`
  take `--plain` for text a person reads; a refusal stays words on standard
  error with exit 1. `install-agent-hooks --print` is the one exception: it
  prints the agent's file as a write makes it, as it did before the other
  commands came, so `> ~/.codex/hooks.json` writes a working file.
- **`tabs list` and `tabs show` include file tabs**, `kind` saying which. A file
  tab carries `path` and `isDeleted` and no `focusedPane`, `panes` or `layout`.
  Cost: a script reading panes off every tab filters on `kind` first.
- **A tab asked for in a worktree out of view opens there without switching to
  it**, so a script does not move the user's view. A worktree with no shells yet
  starts its saved tabs with it.
- **A project or worktree is named on the command line by a short id**, `p-` or
  `w-` and eight hex digits of a hash of the path the model keys it by. Reversed
  2026-10-10 from the path itself, with a folder inside one naming it too: the
  user wanted a path only where one is the input, which is `projects add` and
  the file `debug screenshot` writes, and an id the lists print everywhere else.
  Nothing new is saved, so the id is the same every run. Cost: a moved folder
  gets a new id, as the model already makes it a new project; and two paths
  whose hashes meet would share one, the first listed answering, which at 32
  bits a sidebar's few dozen never reach.
- **Global settings go through a key table, project settings through their
  JSON.** Each global has its own setter with side effects, so each key calls
  it; a project's are one struct saved whole. Keys are the state file's, never
  renamed. The shared-settings trust answers are left out: only the app's own
  question may give them.
- **A global value the Settings window could not set is refused**, not stored or
  clamped: a font family this Mac lacks, a size off its slider's range. A
  clamped write answered done and read back as another number.
- **Waiting and following are polled from the helper.** `panes wait` and
  `debug samples --follow` send a short request every quarter or half second and
  the app answers each at once, so a long wait holds no connection open in the
  app and a helper killed mid-wait leaves nothing behind. Cost: a look every 250
  ms, a pane read or a describe, each a main-thread turn. A samples look asks
  for the newest two, and for thirty only where it finds it missed some.
- **A wait with `--scrollback` reads the scrollback at its first look only**,
  then the screen. Ghostty keeps up to 50 MB of it by default, read under the
  renderer lock on the main thread, so a full read each look holds the window
  that long four times a second. Cost: a match that scrolls past a whole screen
  between two looks is missed, as it is for a wait without the flag
  (`aWaitInTheScrollbackReadsItOnceThenWatchesTheScreen`).
- **A pane is read as the engine holds it, not as drawn**, through libghostty's
  own text read under its renderer lock: a pane out of view reads as well as one
  on screen, and the text has no colour or layout. The screen read is the live
  one, not the viewport, so a pane scrolled up still shows what comes in.
- **A screenshot is the app drawing itself, not a screen capture**, so it asks
  for no Screen Recording grant. Ghostty presents each frame as an IOSurface on
  the pane's layer, which AppKit's cached window leaves clear, so the surfaces
  are drawn first and the cached window over them: a pane's fade and focus ring
  stay on top, which drawing the surfaces last covered. The app sends the PNG in
  its answer and the helper writes the file, so no request names a path the app
  writes to.
- **A reported state goes through the app's own handling of a hook's report**,
  as a request rather than a report line, so the answer says what the pane then
  shows. It is how the dots, banners and board are tested without an agent.
- **What is up on screen is listed and dismissed from the model**: the alert,
  each confirmation, the shared-settings question, the New Worktree sheet, the
  quick switcher and the name fields, topmost first. Dismissing is each one's
  Cancel, so a script stalled behind a dialog nobody sees can clear it without a
  click. The sheet is only closed: a create running may be a request's, not the
  sheet's.
- **A menu item is chosen by its titles, as a click would**: the menu validates
  first, so a greyed-out item is refused rather than run, and every action a
  shortcut reaches is reachable without one. Titles are in the app's language
  (translation.md). Cost: AppKit inserts View > Enter Full Screen only as the
  menu first opens, so the bar a request walks lacks it until a person has
  opened it; `window full-screen` calls the window's own toggle instead.
- **The banners posted are logged in the app**, the newest fifty
  (debug-tools.md).
- **What a row or a tab shows is listed from the calls its views make**
  (`sidebar list`, `board list`, `tabs show`), so a test reads the values the
  screen draws, not a copy.
- **Every command naming a pane's agent names the one at its prompt**, as its
  mark does. Reading the agent the tab was opened as, `panes show` and
  `tabs list` missed a `claude` typed into a shell tab that `sidebar list` and
  `board list` showed (`aPaneNamesTheAgentAtItsPromptAsTheSidebarAndBoardDo`).
- **`worktrees show` reads git before it answers**, since status is read only
  while the app is frontmost, the Files panel's worktree aside (worktrees.md),
  and a scripted copy usually is not.
- **The settings windows open through SwiftUI's own openers**, which only a view
  can reach, so the root view hands them to the platform. AppKit cannot open a
  SwiftUI scene, and closing one goes by the window's identifier.
- **Auto Rename runs an agent's own CLI once, not an API.** No key to store, and
  the user's own sign-in and plan pay. Cost: an agent's start-up on every run.
- **It sets the display name only**, as Rename does. The branch is what a
  remote, a pull request and every git command track, and Use Branch Name undoes
  it like any rename.
- **Rename model and effort are lists in the catalogue, not text**, or a typo
  reaches the CLI and fails mid-run. Read on 2026-10-24: Claude's and Gemini's
  aliases, the models `codex debug models` lists as visible with each one's
  efforts, Copilot's `help config` list, and for OpenCode the newest of three
  providers', its own list being whichever providers the user set up. Cost: each
  month's releases are copied in by hand.
- **Effort is per model where the CLI says so.** Codex's gpt-5.5 takes no max or
  ultra, so an agent's default model is offered only what every listed model
  takes. Copilot names one set for all, so each model is offered all of it,
  unchecked per model.
- **A stored model the catalogue has since dropped runs as the agent's
  default**, so it is offered and checked against the default's efforts, and
  stays listed in its picker rather than showing blank.
- **Gemini CLI and OpenCode take no effort flag**, Gemini's thinking budget
  being a setting and OpenCode's a model's variant, so they run at their own
  default and the picker is greyed.
- **No Rename agent is the project's agent at its own model and effort.** A
  custom command has no one-shot form the app knows, so with it as the project's
  agent Auto Rename is off until a Rename agent is chosen. A retired Rename
  agent is forgotten on load, as a preferred one is.
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
  runs a repository's hooks in prompt mode is unread.
- **Claude and Codex keep no session of it** (`--no-session-persistence`,
  `--ephemeral`); Gemini, Copilot and OpenCode show no such flag in their help,
  so the run is in their history.
- **It starts in the worktree with `PWD` saying so.** The login shell's
  environment was captured in the home directory, and a CLI exec'd with no shell
  between reads its project from what it is handed.
- **The run's own hooks report nowhere.** Started by the app it has no pane, so
  the helper falls back to the app's socket and its report, naming only a
  directory, would move the worktree's dot and post a Done. `MULTISHELL_SOCKET`
  is `/dev/null` for it.
- **It reads commits and the index against the Branch view's base**,
  `diff --cached <merge-base>`: unstaged and untracked work is often half done
  or a stray. A branch sharing no history with the base says so rather than that
  nothing is committed; one with no commit yet is read from the empty tree, its
  staged files naming it. Merge commits are left out of the subjects, which say
  what came in rather than what the branch does. At most 50 subjects, a diffstat
  of 60 files and 20,000 bytes of diff, cut at a line and said to be cut, a
  small part of any listed model's window. A NUL in a text diff is taken out,
  the prompt going as one C-string argument that would end there. The stat and
  the patch come from one `diff`, git computing a large branch's once. Cost:
  git's whole diff is read before the cut, so a branch adding a large generated
  text file holds it in memory for the run.
- **Off where nothing is known to be there**: nothing staged and no commit of
  its own, at its base's tip, landed on it at the tip and against the base it is
  still at, or the trunk behind a remote base after a fetch with nothing
  unpushed, which the merge badge leaves unread. Read from what the status read
  and the branch scan already hold, so a menu costs no git. The scan, not the
  worktree's listed `HEAD`: a commit moves a ref the scan reads at once, and the
  listing waits. Where they have not answered it runs and says there was
  nothing.
- **A bare repository's row is never offered**: its empty index reads as a
  branch deleting every file.
- **Before the login shell has answered, a run says the agent is still being
  looked for**, not that it is missing.
- **The name is the reply's first line with a letter or digit**, a code fence,
  escapes and control characters, a joiner or direction mark staying, a label,
  bold or not, and markdown or quotes wrapping the whole line taken off, cut at
  a word to 48 characters. Escapes are ECMA-48's whole forms, `ESC c` and
  `ESC % G` among them, a CLI's colour taking more than `0-9;`. A quote between
  two letters is an apostrophe, so `'Fix user's avatar'` loses its quotes. Marks
  inside the name stay, `__init__` being a name.
- **A reply about what no longer stands names nothing**: the worktree turned to
  a branch neither the click's listing nor the run's own read of `HEAD` saw, or
  the user named the row or opened its field, theirs outranking the agent's. The
  read's branch, not the listing's, is what the agent is told, the listing
  lagging a checkout made in a pane, and a detached `HEAD` is told as detached.
- **The agent's words are their end, 300 characters cut at a line**: standard
  error then standard output, as a Node warning on one would hide an error on
  the other, and Codex prints its banner and the prompt to standard error and
  the error last. Its styling is taken out as a reply's is, a login shell's
  `FORCE_COLOR` reaching the Node CLIs.
- **Removing the worktree or quitting stops its run**, through the stopper it
  was started with: the agent otherwise spent the user's quota for up to 90
  seconds in a directory gone, or with no timer left after a quit to end it. A
  run stopped before its launch starts no agent, and one stopped while a new run
  began at the same path answers nothing, the runner keeping one stopper per
  worktree.
- **A failure stays on the row as a warning until clicked, and posts a banner
  behind the Failed toggle**, the user's pick on 2026-10-24 over an alert, which
  could land up to 90 seconds after the click on whatever was being typed. It
  goes through the notification policy an agent's failure does, so none is
  posted for a row in view with the app in front, and its title names the
  project. Only what the agent answered gets one, a failure known at the click
  itself being answered by the row the user is looking at. The banner's key is
  the worktree's, so a click selects the row; it goes as the warning is cleared,
  the row is looked at, a new run starts or the worktree is removed. Cost: it
  shares that key with a directory report's banner, so either takes the other's
  back as it goes.
- **VoiceOver says the row's Auto Rename failed, and the reason as its hint**,
  up to 300 characters of an agent's words being too many for every visit.
- **Ninety seconds, then it stops**: a long diff on a slow day takes tens of
  seconds, and past that nobody is watching the row. Cost: the bound and a
  removal's stop cover the agent, not the git reads before it, which take no
  stopper; a hung volume holds the row's spinner until git returns.
- **OpenCode 2 alone is supported**, the user's call on 2026-10-27: 2 runs no
  plugin written for 1.x, and one file serving both kept a second adapter to
  test for a line about to go. The plugin is a default export of an `id` and a
  `setup`, still at `plugin/multishell.js`, which 2.1.4 scans beside `plugins/`,
  so an install from an older build reads as needing Update.
- **The bus carries every directory's sessions**, the background service running
  them all, and each directory loads the plugin once. An event's envelope may
  name its directory, and a run's events did not in the probe, so the plugin
  keeps the sessions its hooks named and those created here, and asks about any
  other, remembering the answer. Read from the 2.1.4 binary and a probe on
  2026-10-27, not seen for a global plugin across two directories.
- **An envelope naming another directory settles it unasked**; one naming this
  one still asks, as only the answer says whether the session is a child, and an
  answer naming another directory outweighs it. A location naming no directory
  says nothing, in an envelope, a creation or an answer, and leaves the record's
  source as it was, or an answer naming no directory outranked the envelope that
  asked for it (`anAnswerNamingNoDirectoryLeavesALaterEnvelopeToSay`).
- **Only the events the plugin reads are queued**, a session's creation and move
  and the six it looks up for: a streamed part names its session too, and one
  whose lookup failed was asked about again for each part
  (`anEventThePluginDoesNotReadAsksNothing`).
- **A session the TUI moves to another worktree is placed by its new location**,
  as `session.moved` says: kept here, the old worktree's dot showed the new
  one's turns (`aSessionMovedAwayIsAnotherDirectorysAndOneMovedHereIsThisOnes`).
  Moved away, mid-turn, after its Done or while asking, it ends here: its
  children end and are dropped, filed with it as elsewhere's, and it goes Idle
  wherever it stood, or the old worktree kept work now running elsewhere
  (`aSessionMovedAwayMidTurnLeavesItsTurnAndChildrenEndedHere`,
  `aSessionMovedAwayAfterItsDoneOrWhileAskingGoesIdleHere`,
  `aMovedSessionsChildRunningLaterReportsNothingHere`). A move ends it here with
  no placement record too: it goes Idle if the tracker remembers it reporting
  here, its latest 512, or if a session under it on the roster leaves with it,
  running or ended, as either's end woke its turn; for one with a parent that
  end woke its parent's turn instead
  (`aSessionForgottenAmongTheLatestStillEndsHereWhenMovedAway`,
  `aParentUnseenHereThatMovesAwayMidTurnLeavesTheWorktreeIdle`,
  `aChildTheRosterForgotSendsNoIdleWhenItLeavesWithAWorkerUnderIt`). The
  sessions leaving with it are those the roster or the placement records put
  under it, as the roster passes a forgotten parent's children up
  (`aChildLeavingTakesTheGrandchildTheRosterPassedUpToItsSession`). Each is
  dropped outright, taking no place among the 64 ended, or another session's
  oldest ended child was forgotten
  (`aMoveAwayForgetsNoOtherSessionsEndedChild`). A move back takes its children
  out of elsewhere's again (`aSessionMovedBackGetsItsChildrenBack`). A child
  whose parent moved away is elsewhere's, whatever an older answer says, unless
  a hook named it here after the move, and so is any session further down that
  line, though an answer filed the one between
  (`aChildAnsweredAfterItsParentMovedAwayIsElsewheresToo`,
  `aHookNamedChildOfAnotherDirectorysSessionStaysHere`,
  `aGrandchildAnsweredAfterItsSessionMovedAwayIsElsewheresToo`). A session moved
  here brings every session filed elsewhere under it, its children's children
  too, as each one's record keeps its top-level session through an event naming
  no parent (`aSessionMovedHereBringsItsChildrenFromElsewhere`,
  `aSessionMovedHereBringsItsChildrensChildrenToo`,
  `aMovedChildsEventElsewhereKeepsItFiledUnderItsSession`). A lookup answered
  after the move cannot bring it back (`aLateAnswerDoesNotUndoAMove`).
- **A session a hook named stays here whatever a late answer or its creation
  says**: hooks fire only for this directory's sessions, and where it ended up
  turned on whether the answer beat the bound
  (`aSessionAHookNamedStaysHereWhenALateAnswerNamesElsewhere`,
  `aSessionAHookNamedStaysHereWhenItsCreationNamesElsewhere`).
- **An answer naming a parent makes a child of a session a hook or envelope
  placed here**, though the parent is unknown after a reload or forgotten past
  1024, whether the answer came within the bound or after it
  (`aSessionWhoseAnswerNamesAParentIsAChildWhereverItWasPlaced`,
  `aLateAnswerNamingAParentMakesAChildOfASessionAHookNamed`).
- **A child's record keeps its parent**, from a creation as from an answer, so
  one a hook named first is still a child once the roster forgets it
  (`aChildAHookNamedBeforeItsCreationStaysAChildOnceTheRosterForgetsIt`). A
  creation naming a parent makes a child of a hook-named session as an answer
  does (`aCreationNamingAParentMakesAChildOfASessionAHookNamed`).
- **A child of a session here is here whatever its own location says**, in a
  creation or a lookup's answer; read by its location alone, a resumed child's
  answer naming no directory made it a parent
  (`aChildWhoseAnswerNamesNoDirectoryIsStillAChildOfAParentHere`). A parent
  unknown here is asked about once its child is placed, after a reload as for a
  middle session silent on its task, so a move of the top-level session takes
  the whole line (`aGrandchildUnderAnUnknownParentLeavesWithItsMovedSession`).
- **A child the roster forgot rejoins it from its record** when it is resumed,
  past the 64 ended; kept as a plain session here, its resumption read as the
  parent's turn and announced Done
  (`aChildTheRosterForgotIsReadAsAChildWhenResumedNotAsTheParent`,
  `pastTheEndedChildLimitOnlyTheOldestLeavesTheRosterAndRejoinsAsAChild`).
- **Each session's events wait only for that session's lookup**, which has no
  bound. One queue for the whole bus held a parent's Done behind another
  directory's lookup, landing after the next prompt's Working
  (`aLookupForAnotherSessionHoldsBackNoEventOfThisOne`). A hook's lookup keeps
  its one-second bound, and an answer landing after it still counts.
- **A session's hooks take their place in the same queue**, the hook waiting at
  most a second for its turn: a hook-named session is here before its lookup
  ends, and an event during the lookup is reported after the hook's Working, not
  dropped or overwritten (`anEventDuringAHooksLookupIsTheHookedSessions`). An
  event waits up to a second for a hook's lookup still out, as its answer may
  make a child: read before it, a resumed child's end was the parent's Done and
  the late answer started a worker that never ended
  (`aChildWhoseRunEndsBeforeItsLateAnswerEndsAsAChild`). An answer past that
  second, after the session's own run ended, starts it on the roster and ends it
  at once, read from its last own report: kept started, it was out in every
  later Done, and joined silently, the worktree stayed on its Done mid-turn
  (`aChildWhoseRunEndedBeforeAnAnswerPastTheBoundJoinsTheRosterEnded`). After
  the parent's own Done it joins ended and silent, or its end over that Done
  left the worktree Working with no Stop to come; a grandchild reads its
  top-level session's Done, its own parent having none
  (`aChildWhoseLateAnswerLandsAfterItsParentsDoneJoinsTheRosterQuietly`,
  `aGrandchildWhoseLateAnswerLandsAfterTheSessionsDoneJoinsTheRosterQuietly`). A
  prompt it raised as its own is answered there and raised again as the
  worker's, or the reply, now the worker's, left the agent's prompt standing;
  one any session is raising as its own stays up, as all share the agent's
  prompt (`aPromptAChildRaisedAsItsOwnBecomesTheWorkersOnceItsLateAnswerLands`,
  `aChildsLateAnswerLeavesItsParentsOwnPromptStanding`,
  `aChildsLateAnswerLeavesAnotherSessionsPromptStanding`).
- **Each session has one placement record**: here or elsewhere, the source that
  said so and when, its parent and agent. A source overrides the record unless
  one ranked above it set it: a hook or a move outranks a creation or an answer,
  and those outrank an envelope; between equals the newer wins. A parent moved
  away after a session was placed takes it along, a hook's word too, as the
  answer naming that parent can land after the move
  (`aChildAHookNamedBeforeItsParentMovedAwayIsElsewheresOnceAnswered`); a hook
  naming it again after the move stamps it anew and keeps it here
  (`aChildAHookNamesAgainAfterItsParentMovedAwayStaysHere`). A hook counts from
  when it fired, not when its turn in the session's queue came: one fired before
  the move but run after it kept a moved child here
  (`aHookThatFiredBeforeItsParentMovedAwayKeepsNoChildHere`). The precedence
  spread over four maps read worse and drifted between them.
- **A session leaves here one way, whatever filed it elsewhere**: a move, an
  answer or an envelope re-files every session under it and drops them and the
  session itself from the roster. An answer that left the children's records
  here put them back on the roster in the old worktree
  (`aSessionAnAnswerFilesElsewhereTakesItsChildrenAlong`), and a child filed
  away by an envelope stayed out in its parent's Done for good
  (`aChildAnEnvelopeFilesElsewhereLeavesItsParentsRoster`). The sessions under
  it take the word that moved it, so one that outranks it brings them back
  (`aSessionBackHereAfterAnEnvelopeFiledItElsewhereBringsItsChildrenBack`). A
  session with a record moves them only on a change of place: another
  directory's session moving to a third left its child here dropped
  (`anotherDirectorysSessionMovingElsewhereLeavesItsChildHereAlone`). A session
  whose record was forgotten still ends here if it reported here, its children
  with it
  (`aSessionWhoseRecordWasForgottenGoesIdleWhenAnEnvelopeFilesItElsewhere`,
  `aForgottenSessionAnEnvelopeFilesElsewhereTakesItsChildrenAlong`); another
  directory's session an envelope shows for the first time never moved, and its
  child here runs on
  (`anotherDirectorysSessionFirstSeenAfterItsChildIsHereLeavesTheChildRunning`),
  but a parent unseen here that the TUI moves away takes its child along
  (`aParentUnseenHereThatMovesAwayTakesItsChildAlong`). Any arrival here, and
  any move here though the record already said here, has an envelope-filed
  session asked about again
  (`aSessionAHookBringsBackAsksAgainAboutAChildAnEnvelopeFiledElsewhere`,
  `aMoveHereOfASessionAlreadyHereStillAsksAgainAboutAnEnvelopeFiledChild`). The
  session joining the roster forgets its own reports, or one that reported as
  its own before its parent was known sent a stray Idle long after its parent
  moved away, from the roster or forgotten by it
  (`aChildThatOnceReportedAsItsOwnSendsNoIdleLongAfterItsParentMovedAway`,
  `aChildTheRosterForgotSendsNoIdleLongAfterItsParentMovedAway`).
- **A top-level session is walked up the parents at each use**, never stored: a
  parent learned after its child, from a late answer, left the grandchild out of
  the Done and behind on a move away
  (`aGrandchildCreatedBeforeItsParentsLateAnswerCountsUnderTheTopLevelSession`).
  An ended child the roster forgets passes its children to its own parent, so a
  grandchild still running stays under its session
  (`aGrandchildStillRunningCountsUnderTheSessionOnceItsEndedParentIsForgotten`).
  A move re-files every record under the session, here or elsewhere, rather than
  dropping them, or a grandchild seen before its parent was filed by its own
  location
  (`aSessionMovedHereBringsAGrandchildWhoseEventComesBeforeItsParents`).
- **An envelope's word gives way to a later envelope naming the other side**: a
  child an envelope filed elsewhere is asked about again once its parent is
  moved here (`aChildAnEnvelopeFiledElsewhereComesBackWithItsMovedParent`). An
  envelope names no parent, so a session it filed elsewhere before any move here
  is asked about on its next event, whatever that event's envelope says
  (`aChildAnEnvelopeFiledElsewhereIsAskedAgainOnceItsParentMovesHere`).
- **The records are bounded at 1024 for each place**, the service running for
  days, so other directories' sessions never push out this one's
  (`aSessionAHookNamedKeepsItsPlaceWhileOtherDirectoriesSessionsComeAndGo`). One
  forgotten costs a lookup, so a session a hook named is asked about again once
  forgotten (`aSessionAHookNamedIsAskedAboutAgainOnceForgotten`); a child still
  on the roster counts as here without one
  (`aChildOnTheRosterWhosePlaceWasForgottenStillEnds`). The sessions' last own
  reports are bounded at 512.
- **Under the service the helper is told of no tab**: the service keeps the
  environment of the tab that first started it, so every tab's sessions named
  that one. The plugin reads `--service` in its process's arguments and hands
  the helper an environment without the tab's session, worktree, socket and app,
  so the helper finds the app's socket itself and the report marks the worktree
  by its directory. A TUI started with `--standalone` runs the plugin in its own
  process and keeps the tab. Cost: two OpenCode tabs in one worktree share one
  dot.
- **A run's end is one of three events**: succeeded is Done, failed is Failed,
  and interrupted by the user is Idle, as Codex's `Interrupt` is, nothing having
  finished. A run superseded by a prompt sent mid-turn reports nothing, the next
  run carrying on. A failed run's error message is the report's. One ended for
  inactivity is Failed, never having finished. A shutdown is the service going,
  so it reports nothing and the pid poll clears the pane as the service's pid
  goes.
- **A cancelled child wakes its parent in 2**, which hears of it as a message,
  so no end the plugin sends says it wakes nobody.
- **No hook of the plugin's may throw**: a throw fails the user's prompt or tool
  call, so every hook and event body swallows its errors.
- **It subscribes before it registers its hooks**, the bus replaying nothing. A
  hook that fails to register aborts the subscription before `setup` throws:
  OpenCode counts that plugin as failed, and its loop read on with nothing to
  stop it (`aSetupThatFailsToRegisterAHookStopsReadingTheBus`).
- **Each session's last Working is its own**: two sessions in one directory
  shared one, and one's Done swallowed the other's (`eachSessionsDoneIsItsOwn`).
  A run's end arrives once in 2, so no second Done is dropped.
- **A creation naming no directory is asked about**, not filed as another
  directory's.
- **Antigravity CLI is a sixth agent beside Gemini CLI**, which Google stopped
  serving on personal plans on 2026-06-18 but which Standard and Enterprise
  licences and API keys still reach; the user kept both on 2026-10-27.
- **Its hooks go in `~/.gemini/config/hooks.json`**, Antigravity reading none
  from its settings file, as sets of hooks by name. Ours is the set
  `multishell`, merged into as a settings file is: Remove takes out our hooks
  and keeps one of the user's put there, and a set left holding only its
  `enabled` goes. Update keeps the set's `enabled` as it found it, so a set the
  user switched off stays off.
- **Its payload names no event**, so the hook line does with `--event`, and is
  camelCase: the first of `workspacePaths` is the directory, the hook running in
  the folder that holds its file. Read from a probe of 1.4.8 on 2026-10-27.
- **Its timeout is in seconds**, unlike Gemini's milliseconds: Antigravity's
  hooks page gives seconds with a default of 30, and the probe's hooks, given 5,
  ran their whole process walks, which a 5 ms limit would have killed.
- **Six events, and none says it waits for the user**: PreToolUse fires before
  the approval prompt, and nothing after it. A pane shows Working through a
  permission prompt. Antigravity says waiting through OSC 7501, which it probes
  for and our terminal does not answer; reading it is a Ghostty patch, not
  taken.
- **Each model call is a turn start**, PreInvocation firing per call with no
  sign of the user's prompt bar `invocationNum`. Antigravity has no worker the
  roster counts, so a start mid-turn clears nothing.
- **A Stop's `terminationReason` picks its state**: `USER_CANCELED` is Idle,
  `ERROR` is Failed, the rest Done. A failed Stop's non-empty `error` is the
  report's message.
- **PostToolUse is not asked for**: a backgrounded command's arrives as it
  exits, after the turn's Stop, and put a finished pane back to Working.
- **No background shell or subagent is counted**: no event names a subagent, and
  how a backgrounded command's process reads is unread. A pane waiting on one
  goes Done at the Stop.
- **A hook printing nothing and exiting 0 lets the tool run**, and one exiting 1
  after a tool is logged, both seen in the probe.
- **Its one-shot run is `--mode plan --print=<prompt>`**, `--print` taking the
  prompt as its value, models and efforts as named in the 1.4.8 binary. Cost:
  plan mode makes no edit but no flag takes a tool away, and the list is not
  checked against `agy models`, which reads the account.

## Reviewed and left as is

- **`--subagent-wakes` with nothing in the repository sending `false`** (round
  1, 2026-10-28): it is an option of the helper's `state` command, which a
  user's own script or plugin may send, and fields are only ever added. The rule
  that a cancelled worker's end says so stands for any reporter that knows it.
- **A closed bus stream is not subscribed to again** (round 1): nothing shows
  2.1.4 ending the stream while the plugin runs, and a reload calls `setup`
  afresh. Unproven, so no retry loop.
- **A prompt sent mid-turn starts a turn, emptying the roster** (round 2): the
  prompt hook's `delivery` cannot tell it apart, the probe of 2.1.4 showing an
  idle session's first prompt as `steer` too, and whether a superseded run keeps
  its children is unread.
- **Antigravity's directory is the first of `workspacePaths`, over the tab's
  worktree** (round 3): a report from a tab names its session, which decides the
  pane; the directory places only one naming none, and Antigravity lists the
  workspace it started in first.
- **A named set's `enabled` handled in `hooksObject`, `isLeftEmpty` and
  `replacingOurs`** (round 3): round 2 put the restore in one line of
  `replacingOurs`; moving the drop from `removing` to Remove is another shape
  for the same behaviour, which is tested, so it stays.
- **A lookup that never settles holds its session's queue for good** (round 4):
  an unbounded lookup was round 1's fix for a slow one dropping a session, and a
  `session.get` that never settles is a wedged service.
- **A switched-off Antigravity set still reads as current in Settings** (round
  5): Update keeps the switch as the user left it, and a state of its own for a
  switched-off set is a feature, not a fix.
- **A prompt reports a new turn once its lookup's one-second bound runs out**
  (round 6), even where the late answer would show a resumed child: the bound
  keeps OpenCode's hooks from waiting, and the answer still puts the child back.
  Until then the child reports as its own session and shares the agent's one
  prompt on the dot, so its Working can answer the session's or a sibling's
  prompt (round 48); a prompt per session is a redesign of the app's prompt
  raisers, not a fix. A hook whose own wait runs out with its lookup's returns
  before its report, which can then land after another session's event (round
  49).
- **An Antigravity payload that is not a JSON object reports nothing** (round
  7): the probe of 1.4.8 saw an object on every event, and a report made up from
  the hook line alone would be a guess.
- **Antigravity's Stop `fullyIdle` is not read** (round 8): the probe saw it
  true on every Stop, and what false would mean is unread, so a Stop is Done by
  its reason alone.
- **The plugin compares directories as OpenCode spells them** (round 8): the
  plugin's location and a session's come from the same server, and the probe saw
  one spelling; resolving links on every event costs a call each.
- **A late event for a child forgotten past the 64 ended starts it again**
  (round 11): its lookup names a parent, as a resumed child's does, and only its
  own next run would end it; the 1.x plugin did the same, and it takes 64 ended
  children and then a stray event. A move away and back reaches it too, its
  ended children having been dropped at the move (round 56).
- **A child located here whose parent is another directory's joins this roster**
  (round 15): a session located here is this directory's by the plugin's own
  rule, and nothing shows OpenCode placing a child apart from its parent.
- **`ourGroup` deciding a named set's entry shape beside the format switches**
  (round 15): it is the one place both the write and the merge take an entry's
  shape from, so the merge cannot write a shape the write does not.
- **Antigravity's `--continue` after an Auto Rename run** (round 17): it picks
  the latest conversation in the workspace, by the research of 1.4.x, so tabs in
  other worktrees keep their own, but a rename run in the same worktree may be
  the latest. The cost already recorded for Gemini, Copilot and OpenCode, whose
  runs also stay in their history.
- **Other Antigravity products firing our hooks** (round 17): unread whether any
  read `~/.gemini/config/hooks.json`; a run outside a pane reports by directory,
  as every agent's does.
- **A child created under an ended child is placed here** (round 18): unread
  whether OpenCode creates one, the app draws a worker whose parent is no longer
  out at the top, and the ended child's next run puts it back on the roster.
- **A session no answer can place is asked about at each event** (round 21):
  every session the probe saw carried a location, and a failed lookup asked
  again was round 1's fix for one that would otherwise be dropped for good.
- **Events queued before a hook fails to register may still report** (round 21):
  the window is between the subscription and one registration rejecting, and
  nothing shows it reached.
- **`reportsWaiting` true for any plugin** (round 21): OpenCode's is the only
  plugin and reports Waiting; another would say so when it comes.
- **A creation naming no session** (round 22): the worker it would store under
  no id never reaches the app, its report failing to spawn, and lists as nothing
  in a Done; no observable effect was found.
- **A grandchild whose parent was forgotten counts under that parent** (round
  24): outside the service a Done then leaves it out, but it takes 64 ended
  children and a late event or resume of the grandchild.
- **Under the service a move away's Idle settles the worktree's one entry**
  (round 25), another session's turn there with it: the cost recorded for two
  OpenCode tabs in one worktree sharing one dot. Two sessions in one standalone
  TUI share its tab's dot the same way (rounds 46 and 50): a child that reported
  as its own before its late answer, landing after its parent moved away, sends
  its own Idle over the other session's turn.
- **Two walks for the sessions under one** (round 31): the tracker walks the
  roster and placement walks the records, each its own store, through one
  `ancestorsOf`. A roster child's parent passed up when its ended parent is
  forgotten has the same top-level session either way.
- **A child the TUI moves by itself** (round 32) is ignored by `onMoved`, and a
  later move of it can send a stale Idle: nothing shows OpenCode moving a child
  apart from its parent.
- **A move here re-asks every envelope-filed session elsewhere** (round 32), one
  lookup each on its next event: an envelope names no parent, so any of them may
  have come with the move, and moves are rare.
- **A running child left out of a Done after a move here mid-turn** (rounds 33
  and 42), until the child's next event rejoins it, and a grandchild's rejoin
  leaves it out still while its parent stays off the roster (round 52):
  rejoining every re-filed session at the move would mark ones that ended long
  ago as started. A forgotten session filed back here by a hook also leaves its
  moved children elsewhere, which needs OpenCode to change a session's place
  without `session.moved`.
- **A child's run end read from `reported`** (round 43): past 512 other sessions
  reporting while its lookup is still out, or a permission reply after an
  interrupt, its late answer starts a worker that never ends. The first is the
  wedged service of round 4; nothing shows the second.
- **`recordedDescendants` beside the roster walk** (round 43): the roster passes
  a forgotten ended parent's children up, and the records forget too at 1024, so
  neither store alone names every session leaving; the move merges both.
- **`relocate` scans every record** (round 33), up to 2048, to find one
  session's children. It runs on a change of place and on any move of a session
  with no record, in each directory's plugin; moves are rare, and an index kept
  on every write costs more than the scan.
- **A child leaving after its parent's Done listed a grandchild sends no Idle**
  (round 41): the grandchild's end report then waits on a parent turn that may
  not come here. It needs an envelope naming another directory for a child here
  and an unread answer to whether the child's woken run wakes its parent.
- **The 65 ended children in
  `aChildTheRosterForgotSendsNoIdleWhenItLeavesWithAWorkerUnderIt`** (round 41)
  change no report under the parent-fact guard; they are the path on which the
  roster-based guard round 39 replaced sent the Idle.
- **A session a hook named is asked about once** (round 55), however that lookup
  ends (`theParentIsLookedUpOnceHoweverTheLookupEnds`): a resumed child whose
  one lookup fails reports as its own session for good. Asking again on each
  hook costs a lookup per tool call, for a `session.get` failing once, which
  nothing shows.
- **"child" and "worker" in the plugin** (round 12): a child is OpenCode's
  session relation, by `parentID`; a worker is the roster's entry the app
  counts. `isWorker(parentID)` asks whether the parent is on the roster.

### Asked both ways

- **A standalone Done listing every session's children or only its own** (round
  52): two sessions in one standalone TUI share its pane, so its own list drops
  the other's running children until their next report. Kept its own
  (`aSessionsDoneListsOnlyItsOwnChildrenAsOut`): the cost is round 25's shared
  dot, and only the service, every tab's sessions in one plugin, lists all.
- **An unseen parent's move away, with its child here** (rounds 34 and 35): the
  plugin cannot tell a parent of another directory moving between two others
  from one of this directory it never saw, after a reload or forgotten. The
  child leaves with it: OpenCode runs a child in its parent's worktree, and a
  child here under another directory's parent is round 15's unseen premise.
- **Antigravity's Stop listed three times under reported names, and
  `hooksObject` writing each name once**: round 4 asked for the write-once skip
  so the last of three identical entries did not silently win; round 5 asked to
  drop the three entries for one Stop whose state follows the payload's reason.
  Kept round 4's: every event keeps one state, as the other agents' do, and the
  skip is tested by every install test.
- **An envelope naming another directory, against a resumed child placed
  there**: round 1 had the envelope settle another directory's sessions unasked,
  sparing every directory's copy of the plugin a lookup per foreign session;
  round 14 asked for a lookup so a resumed child located elsewhere, its creation
  unseen, joins its parent here. Kept round 1's: a child whose creation is seen
  is placed by its parent, and the other case needs a resume with no creation.
- **A lookup's answer against an envelope naming this directory**: round 2 had a
  lookup naming another directory outweigh the envelope; round 14 asked for the
  envelope to win where the answer names a subdirectory. Kept round 2's: the
  answer is the session's own location, and a session in a subdirectory has its
  own copy of the plugin there.
- **`hookLineNamesEvent` as a switch or `self == .antigravity`**: round 1 wrote
  the comparison, round 12 asked for a switch so a new spelling must answer, and
  round 18 asked for the comparison again. Kept round 12's switch.
- **The plugin source test checking each state's report call**: round 6 loosened
  it to any quoted state, round 13 restored the calls so a state no call sends
  fails it, and round 21 asked to drop it as rename churn. Kept round 13's, the
  behaviour suite not checking each state is spelled as the helper takes it.

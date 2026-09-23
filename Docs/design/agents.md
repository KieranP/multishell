# Agents

The inbound channel, each agent's hooks, and the board that shows them. Newest
at the bottom.

- **The inbound channel is a Unix socket and a small helper.** Not a URL scheme,
  which would activate the app dozens of times a minute; not netcat, for the
  quoting, a stable protocol and one place for each agent's mapping.
- **Fields are only ever added.** A report naming an unknown session is dropped,
  not matched by directory.
- **One naming only a directory marks the deepest worktree containing it**, so
  an agent started in a subfolder says that folder, and a worktree nested in
  another is the one meant.
- **The pid a report names is what the app polls** to clear a Working the agent
  never took back.
- **The app hands each session its own pid**, or the helper's walk past the
  shells reaches the app itself, whose pid never goes while it looks. A report
  naming it anyway, from an older helper, is taken as naming none.
- **A report carries only what the app cannot see itself**: state, pid, message,
  a duration so a fast command posts no banner, and the agent, a pane's agent
  usually being started by hand.
- **It moves a dot, raises a notification and decides how a dropped file is
  written.** It opens no tab, runs no command and puts no text at a prompt.
- **Shell reports run inline**, or a fast command's finished overtakes its
  started.
- **Four agents share one hook line and one parser**, each running a command at
  every lifecycle event with the same three fields. What differs is the file,
  what each calls an event and how that file spells a hook.
- **The app knows no agent by name anywhere else.**
- **Each is asked in its own spelling**: one has a permission request where
  another has a notification, one has both and is asked for both, and one is
  asked in the spelling whose payload names its event.
- **One counts its timeout in milliseconds**, where the obvious number would
  kill the helper before it reached the socket.
- **One reads a directory of hook files rather than a settings file**, so its
  file is ours alone: written whole, deleted to remove, no copy kept.
- **One reports to no command at all**, only a plugin seeing a session go idle,
  so it is given a plugin calling the helper as any script would.
- **That one is also the only agent that says a permission was answered**,
  allowed as well as denied, so it is the only pane whose Waiting clears on the
  answer rather than at the next tool call.
- **Its permission-ask hook is deliberately not used**: uncalled since its
  permissions rewrite, and the day it is called again it would report a prompt
  the event bus already reported.
- **Cost of the plugin**: JavaScript in the user's agent, so it spawns, unrefs
  and swallows everything, and it is the one integration whose contract we do
  not control from a payload.
- **Four events are narrowed**, "the agent raised a notification" not being "the
  agent is waiting".
- **One raises a notification when a background shell finishes** as much as when
  it needs an answer, so ours asks for the two types that are questions.
- **One has no notification, only a permission request that fires before it
  decides whether anyone need answer**, so under a full-auto mode every tool
  call would have posted a banner. It counts as waiting only in a mode that
  stops for the user, and an unknown mode is taken to stop.
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
- **Sorted from the payload's own type, not the matcher the event takes**: a
  matcher is written into the settings file, so it would reach only installs
  made after the build that adds it, and an agent old enough to send no type
  would match none of them.
- **A main-loop stop is not the turn ending.** A subagent launched in the
  background outlives it and its tool calls keep reporting, so the pane went
  Done, Working, Done again, once per wave, each with a banner.
- **So the subagent start and end are asked for too**: a stop with any
  outstanding is held as Working, and the last worker to end pays the Done the
  agent was owed.
- **What is outstanding is a roster the app keeps**, a hook being a fresh
  process with nothing to remember. An agent that reports no workers never
  enters that arm and keeps stop meaning Done outright.
- **A worker left on the roster costs the Done banner and nothing else.** Idle,
  Failed, the process going or the shell's own command returning clears it, the
  agent having been that command.
- **A worker's start and end carry Working and are bookkeeping, not news**: they
  leave a Waiting or a Failed where it is, or a background worker ending while a
  prompt was up withdrew the banner with the prompt still on screen.
- **Such a tick reports nothing back to the model.** It carries no message, so
  letting it through would replace the prompt's words on the card and post the
  banner again under the same key, which replaces the one already there.
- **A tool call inside a worker is work, as the main thread's is.** The prompt a
  worker's tool raised names the worker, and is cleared by that worker's next
  call rather than held until the main thread moves.
- **One agent's request is asked for beside its notification, not instead**: the
  notification is slower and is dropped if the user answers first, so alone a
  quick prompt never moved the dot and a slow one moved it late.
- **So a prompt reports twice and only the second is heard from**: the request
  moves the dot with no banner, the notification raises it and carries the
  wording, the request having no message.
- **That delay is the agent's own rule for when a prompt is worth interrupting
  someone for.** The general form is silent: move a dot where another report
  about the same thing will do the talking.
- **Nothing reports the answer**, so the dot stays until the next tool call or
  the end of the turn: an approved call taking minutes holds it that long.
- **The denial event is not the missing half**, whatever its name suggests: it
  fires only for a call the auto mode's classifier turned down, and a person
  refusing at the prompt fires nothing.
- **The other agents have nothing of the kind**: one request is already the
  immediate one, one notification has a single type, and one fires before its
  own rules run with a payload that never says the mode.
- **One error event is deliberately left**: it carries a recoverable flag, and a
  red dot for something the agent recovers from is worse than no red dot.
- **The hook line runs the helper rather than exec'ing it, and exits zero
  whatever became of it.** Two agents block a tool call on a non-zero hook exit,
  so under exec a helper killed by Gatekeeper would stop the agent working.
- **Cost: one short-lived shell per event**, the pid coming from walking past
  shells either way.
- **A settings file that is a symlink is written through, not over.** An atomic
  write would leave a regular file where a dotfiles repo's link was.
- **The copy kept sits beside the link**, not in the repo it points into, which
  would leave a file their next status has to explain.
- **Nothing under an event is written over.** Absent means an empty list to add
  ours to; a string, an object or a shape a later version takes is something of
  the user's this cannot put back, so Add refuses and names the event.
- **Remove takes back what Add put in and nothing else**, inside a group as well
  as between them: a group holding one of ours beside one of theirs was written
  by hand, so ours are stripped and the group stands.
- **Dropping at group granularity read as Remove working**, the file even
  shrinking, while an audit hook someone had added to our entry went with it.
- **Numbers are written back as the user spelled them.** Parsed to doubles, a
  short decimal came back long and a round one came back integral.
- **Each literal is carried as a string behind a marker**, drawn once per
  process so a string of the user's cannot be taken for a number on the way out.
- **Only a literal the grammar allows is marked**, the rest left for the parser
  to refuse, and the bytes are decoded strictly first, a lossy decode having
  written a replacement character over a byte of the user's.
- **A settings file that will not read back as plain JSON is refused**, not
  parsed loosely: one agent's takes comments and keeps them when it writes the
  file itself, and a re-serialisation here would take them out.
- **Cost: those users add the entries by hand**, so the alert names the file and
  points at the JSON.
- **One agent will run no hook it has not been told to trust**, so installing is
  not the end of it and the row says so; nothing here can trust a hook for the
  user.
- **No agent is recommended** or has anything of its own outside the catalogue.
  An install prompt for one agent was an endorsement in a workspace built to run
  whichever agent the user already chose.
- **Cost: a machine with none installed gets an empty picker and no help filling
  it.**
- **The Agents board is a roster, not a queue.** Every open pane has a card
  while it is open, moving between columns as its state moves, so nothing is
  hidden by having been looked at.
- **A card goes when its pane closes**, and in one other case: an agent whose
  process has gone leaves a plain shell behind, which the filter hides.
- **Failed waits with Waiting, not in Done**: a failure wants the user, which is
  what that column means, and it leaves Done meaning one thing.
- **They part on a dead process**: a question was a claim about that process and
  goes with it, a failure outlived the thing that failed and stays.
- **The filter is the one control and decides membership alone.** A shell it
  lets in lands where its state says, the injected integration already reporting
  a command started and finished, so a build is Working and a failed test suite
  waits.
- **No duration floor, though the banner policy has one**: a banner interrupts,
  a card does not, and the sidebar dot already goes green for a trivial command.
- **The filter lives on the model, not the view**, because the Dock badge counts
  what the Waiting column shows and must read the same flag. Cost: off again
  after a relaunch.
- **While the board is up, nothing acting on "the tab in front" acts at all**:
  closing would end a shell nobody can see, opening would make a tab appearing
  only once the board is left. One predicate answers for all of them.
- **Showing the board also means no pane is shown**, or the selected worktree's
  Done states clear as it opens and their cards reach Idle having never passed
  through Done.
- **An agent's pid is polled only while the board is up**, one sweep as it
  opens: nowhere else shows a quit agent, and watching always would leave a
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
- **Newest first everywhere**, so an arriving card pushes the rest down a place
  and nothing else about a card moves on its own.
- **Columns share the room down to a floor and the board scrolls past it**, a
  partial column at the edge saying there is more.
- **No end arrows**, which the tab strip needs because a tab scrolled out of
  sight is one you forget exists; the board has four fixed columns.
- **No line of output on a card**: the engine hands no scrollback to the core.
- **Flags are stored per agent id**, not as one line for whichever agent is
  chosen: flags are written for a particular CLI, so a line kept across a change
  of agent is one the other will reject.
- **Cost: switching agent and back is two lines to fill in**, and the settings
  row shows only the chosen agent's.
- **The line is split into words here**, not passed to the shell as text, so a
  branch with a space in it stays one argument.
- **Quotes and backslashes group the way a shell reads them**, down to a
  backslash inside double quotes guarding only the few characters it does, so a
  regex keeps its escapes. Checked against zsh by random lines.
- **A quote left open takes the rest of the line**, there being nobody to ask,
  and an opener carrying nothing passes no argument rather than an empty one.
- **The placeholders are one list**, and the settings rows name one as an
  example rather than all of them: a reference page in a tooltip is what the
  documentation is for.
- **So unlike the hook variables the list is drawn nowhere**, and a new case has
  to reach the docs by hand.
- **An unknown placeholder is left as typed**, so the mistake shows in the tab
  rather than an argument going missing.
- **One pass over what was typed**, so a value holding a token of its own is
  text: a branch named after another placeholder used to have its own name
  expanded again.
- **The branch placeholder on a detached worktree is the short SHA, never
  blank**: an empty value reads as an error the agent reports, where a wrong
  name does not.
- **Flags are appended on resume too.** A tab that comes back continuing a
  session is the same tab, and the flags said how that tab is meant to run.
- **A flag line is not shell text.** Splitting it and quoting each word means a
  branch name someone else pushed cannot run anything: substitutions, backticks
  and semicolons all arrive as literal characters.
- **Checked against a real zsh by random values** over quotes, backslashes,
  shell metacharacters, a space and a newline: every one arrived as the one
  argument meant and none ran.
- **The values are not only branches**, which git keeps tame, but a worktree
  name the user typed and paths that are whatever the directories are called.
- **The same quoting is why a home shortcut or a glob in a flag line is
  literal**, which is the cost: a path there means a placeholder or the custom
  command, which is raw shell by definition.
- **The custom command and the custom editor are shell text**, so a value
  written into them is shell text too: quoted where it landed, a `$(…)` in a
  branch ran anyway inside the user's own quotes, which close or ignore ours.
- **So each placeholder there reads a variable** (`MULTISHELL_BRANCH` and the
  rest, named as the hook variables are where one means the same), set by `env`
  around the login shell so no shell parses a value on the way.
- **The read is quoted for where the placeholder sits**: the user's quote is
  closed, the variable read double-quoted, the quote reopened. That one spelling
  is one word in sh, zsh, bash, dash, tcsh and fish, checked against the first
  five with hostile values.
- **A wrong guess about the quoting costs a split word, never a command**: a
  placeholder inside `$(…)` inside double quotes reads unquoted, and bash splits
  it, but nothing in a value is ever run.
- **Neither flags field carries prompt text.** A greyed example in an empty
  field reads as what the agent is already being started with, and the field's
  whole job is to say what is being passed.
- **The custom command's own prompt stays**: there a greyed example cannot be
  mistaken for a command that is running, an empty field meaning no agent starts
  at all.
- **The project override is a line, not a table**: it overrides whatever agent
  the project runs. Blank is the override to no flags, its only spelling for
  that, which makes it a field where empty is an opinion (settings.md).
- **Flags are not in the repository's file**: a flag is an argument to a
  program, and that file is trusted for what is drawn, not for what runs.
- **Subagents are a roster by id.** The counting events name the worker, and so
  does every hook that fires inside it, so a start or a first tool call puts one
  on and its end takes it off.
- **The count is how many workers those places stand for**, which is more than
  the places only where an agent names two workers alike.
- **Each carries its kind and when it started**, stamped by the model's one
  clock as a state is.
- **Not the tool it is in, though the payload says**: shown, it changed with
  every call and made the list flash; carried, it re-rendered the sidebar per
  call.
- **No task description**: nothing on the wire carries one, for any agent.
- **The wire field is an object with id, type and phase.** The older count field
  is still read, each increment as an unnamed worker, because the helper link is
  shared between builds and points at whichever launched last.
- **The same link makes the reverse meeting happen**, so a start and an end also
  write the count beside the object; a tool call writes none, or each would put
  another unnamed worker on an older app's roster.
- **An interrupt fires no hook and the workers it killed send no stop**, so an
  interrupted fan-out left its chip standing.
- **What says the last turn is over is the prompt that starts the next**, so
  that event empties the roster, nothing owed and nothing lifted, before its own
  Working lands.
- **Cost: the chip stands from the interrupt to the next prompt**, however long
  that is; the pid poll cannot help, the agent being alive at its prompt.
- **A background worker that outlives its turn drops off the chip at the next
  prompt** until its own next tool call puts it back; its stop still takes it
  off, so nothing is owed twice.
- **A worker out is work, the user's rule**: a pane showing Done, or nothing,
  shows Working while any is out.
- **What the worker's report stood over is remembered once**, and the last
  worker out puts it back, so a Done is paid and announced at the end and the
  banner fires once.
- **Provided the worker's start was seen**: one first seen at a tool call after
  the Done was announced lifts it and announces it again, the app having no way
  to tell a late worker from a new one.
- **A Failed comes back unannounced**, having been announced when it happened,
  and only a worker's prompt displaces it, mere work leaving it standing.
- **The agent's own Working takes the dot back for itself**, so the last worker
  out leaves it, and it gives up that claim even where another thread's prompt
  holds the dot, or a Done would fire in the middle of a turn.
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
  is not**, that being the only way an interchangeable worker can answer its own
  prompt.
- **With no unnamed place left it takes the oldest of any kind**: one worker did
  end, and a place left over holds the Done for the rest of the turn.
- **A start or end naming nobody is read as an unnamed worker** rather than the
  agent's own report, and its tool call takes the last unnamed place out rather
  than minting one, which would have left the chip counting tool calls.
- **Per agent, from what each says to a hook.** One spells the two events as the
  first does, behind its own feature flag.
- **One runs a subagent as a conversation of its own**, which fires its own
  prompt, tool calls and Stop under its own conversation id and no worker id.
  Read as the agent's, its Stop put the pane at Done mid-turn, once per worker.
- **So the pane keeps its own conversation's id**, taken from the first report,
  a session start or a Stop, and a report under any other id is a worker keyed
  by it. Its end names that same id as the worker's, so the two meet.
- **Its Stop is told apart without that memory**: the transcript it names is
  filed under its parent's id and never names its own. The helper drops it, the
  end following at once.
- **Not by the transcript's directory**, though that is where the id sits today:
  another agent names the file instead, and under that layout the directory rule
  would have dropped every one of the pane's own Stops.
- **Its start is not asked for**: it arrives in the agent's other spelling,
  which names no id, and one keyed by name alone would never be ended. The
  worker goes on at its own first event instead, so the chip shows no kind.
- **A new conversation of the pane's that sends no session start reads as a
  worker until its Stop**, whose own transcript says it is the pane's; the place
  it held goes then. Cost: Working all that turn, which it was anyway.
- **A start repeated under one id counts its starts and takes as many ends**,
  the alternative being a Done paid while the second is still working; the chip
  counts workers rather than places, so it says two where the list holds one.
- **Nothing says which of them a later report came from**, so neither a tool
  call nor an end under a shared place answers a prompt raised there while
  another worker is on it. Cost: a prompt the asking worker answered stays until
  its sibling's next report.
- **A duplicate start, which no agent documents, would hold the place until the
  turn ends.** That agent's built-in worker emits neither event.
- **One agent names a subagent to its telemetry and never to a hook**, so its
  rows show none.
- **One runs a subagent as a child session**, its plugin reading the child's
  creation as a start, its busy status and tool calls as work, and its idle or
  error as the end. A child's idle is not the pane's Done.
- **Both the old and new spellings of that idle end a child**, the old one being
  deprecated: reading only it in the parent would have left the pane Working for
  good once it is dropped.
- **An ended child's id is kept, marked rather than deleted**, so a second end
  or a late permission of its own is not read as the parent's; a busy status is
  the one thing that puts it back.
- **Ended ids are kept in their own capped list, oldest first**, the cap being
  on that list rather than on the map: gated on the map, a child cycling busy
  and idle grew the list without bound.
- **One place per child there**, so those cycles neither grow the list nor push
  other children out, at the price of a short scan per end.
- **Where the pieces disagree, the pane's dot is what they agree on**: a report
  for a worker not on the roster puts it on, an end for one never seen takes
  nothing, and the roster clears with everything else.
- **The chip is the count behind a branch glyph in the Working colour**, on a
  pane's row and its board card while that pane has a worker out, and on neither
  when it has none: an empty chip would be one more badge on every row.
- **Not on the worktree row**, which was tried: the row already carries four
  badges, and the pane rows say which pane the swarm is in.
- **A report naming only a directory keeps its workers under the worktree's
  key**, which moves the worktree's dot and shows on no chip, there being no
  pane to hang one on.
- **Hovering the chip lists them, kind and time**, in a popover that ticks while
  it is up; nothing else grows, so a large fan-out costs the sidebar no rows and
  the board no height.
- **Chosen over rows under the tab**, which a fan-out would have pushed the next
  project off screen with, and over cards of their own, which broke one card per
  pane.
- **Cost: the list is never on screen unless the pointer is on the chip**, and a
  screen reader gets it as the chip's label rather than as rows.
- **The selected worktree lists its panes in the sidebar**, one row per pane
  rather than one per tab, so a glance says which pane is working and which has
  a swarm without reading the strip.
- **A tab was the row first**, and a split's second pane, which has its own
  agent and its own dot, was nowhere.
- **A split's panes carry a split glyph and their position**, since a renamed
  tab names every pane alike and two plain shells both read as the shell.
- **The worktree row drops its terminal count**, the rows under it being the
  count.
- **The active tab's focused pane is bold, one per worktree**: with two columns
  two tabs are on screen, and two bold rows read as two selections.
- **A click shows another and hands it the keyboard**, the way a board card
  does.
- **Only the selected worktree's**, so one set takes room at a time and a
  project with many panes does not become that many rows. Cost: selecting a
  worktree shifts every row under it.
- **Each pane row's height is what the sidebar's block height counts off**, or
  the drop indicator lands in the wrong half.
- **An agent is drawn as its own mark**, wherever a pane says what it is
  running: the five the app draws, two letters for everything else, the terminal
  glyph for a shell.
- **A mark is recognised without reading**, which is the whole of what a slot at
  the smallest UI font can carry; letters at that size are pairs a glance has to
  tell apart on shape alone.
- **A stock symbol per agent is a mapping nobody can learn**, nothing about a
  generic glyph saying which agent it is.
- **One `.svg` per mark**, a single path in the square the test holds them to,
  parsed once and scaled to whatever the caller asks for.
- **Files rather than hundreds of lines of path calls**: the art is data, a mark
  can be replaced without touching Swift, and a diff of a new mark is one line.
- **Only absolute move, line, curve and close commands are read**, which is all
  those files hold, and anything else is refused rather than drawn half.
- **A file that will not parse is left out of the table**, so the mark draws
  nothing; the test walks every one, which turns that into a failing test rather
  than an empty tab.
- **All five are traced from the projects' own art**, the shape being the
  recognition, from their icon sets and their own icons.
- **One outline is sampled from the icon itself**, radii from its centroid
  through a smooth curve: regular lobes were tried by hand and neither is what
  that shape is, which is irregular.
- **Two marks run to the edges of their square** rather than sitting inset,
  those icons being the mark itself with no padding of their own.
- **One prompt is cut out of its blob rather than drawn over it**, so one fill
  colour carries both; the cut is made when the file is generated.
- **Two are alike at the size a tab draws them and are told apart by their
  tint**, which is the projects' doing and not something to fix by drawing
  either one wrong.
- **A mark black or white upstream is drawn in the theme's text colour**; the
  rest carry the project's own.
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
  pane** with nobody having installed its hooks: the injected integration
  carries the program's name, first word and no path, matched against each
  agent's executable.
- **That answer is held only while the command runs.** What takes it back is any
  report from the shell itself that names no command: the prompt coming back,
  the shell exiting, or the next command.
- **Keyed on the report having no agent, not on its state**: an agent's own
  hooks report running all through a turn and name themselves, and clearing on
  those would drop the shell's answer the moment it started working.
- **Which reports are the shell's is a field it sets**, not a guess: the helper
  is documented for the user's own scripts, and one run from inside a turn
  reports with no agent and no command, which read as the shell's would blank
  the mark.
- **Matched on the executable alone**, so a wrapper invocation is nobody: the
  word is the command. A leading assignment, `command`, `env` or `exec` is
  stepped over first.
- **A word needing JSON escapes is left out of the shell's own line** rather
  than escaped, no agent's name needing one. Cost: a script of the user's named
  after an agent marks its pane as that agent.
- **The state dot badges the mark instead of taking the slot.** A tab has one
  leading slot, which used to hold either the dot or the tab's kind.
- **The dot sits on the mark's lower-right corner, ringed in what is behind
  it**, so a row says what is running and how it is doing at once, and covers
  the mark's edge rather than the middle that carries the shape.
- **Covering part of the mark is the trade, and the right way round**: a state
  is read down a whole strip, a mark only where the eye already is, and an idle
  pane draws the mark whole.
- **The sizes were set by rendering the shapes from tab size up and looking**,
  which is what threw out a hand-drawn mark that read as an animal at tab size.
- **A mark that only works blown up is no mark**, and the box cannot grow to
  help, the tab floor being exactly what a tab already draws at the smallest UI
  font.
- **The tab's dot keeps its click**, which clears a stale Working state, and the
  whole glyph is now that target.
- **A split tab loses its split symbol where an agent is at the prompt**: one
  slot draws one thing, and which agent is working matters more from across a
  strip than which tabs hold two panes. The row still says split to a screen
  reader.
- **A shell the agent backgrounded is a worker too**, the user's rule for
  subagents applied to the other thing a turn leaves running: a pane waiting on
  a build it started showed Done, then Idle once looked at.
- **No hook says a background shell ended**, and none of the notification types
  covers it, so its end is its exit: the pid goes on the roster and the pid poll
  takes it off, paying the Done as the last worker out would.
- **The Stop names them**, there being no tool call in flight at a Stop, so any
  tool shell still alive under the agent is one it backgrounded. The helper
  lists the agent's children and keeps those whose command line holds the
  agent's shell marker.
- **The marker, not "any child"**: MCP servers and the agent's other helpers are
  children for the whole session and would hold every Done forever.
- **Claude's marker is the snapshot every Bash tool shell sources**, matched
  below the config directory so a moved one still matches. It is how the agent
  happens to start a shell, not a contract: if it changes, nothing matches and a
  pane goes Done early, as before, rather than Working for good.
- **One place per pid however many Stops name it**, since a turn woken by the
  shell's output stops again with the shell still listed until the poll sees it
  go.
- **The prompt starting a turn drops them with the rest of the roster**, and the
  next Stop lists them again: during the turn the pane is Working anyway.
- **An unnamed worker's end never takes a shell's place.** A shell is never a
  hook's to end, and one taken that way would be off the roster and unpolled.
- **Cost: a pid reused before the poll looks holds the Done** until the new
  process goes, the poll seeing only that the number is alive.
- **Claude takes another turn when work it left out ends**, a background shell's
  exit or a subagent's end reaching the model as a message, and that turn ends
  in a Stop of its own: seen in a session's own transcript, every such wake-up
  followed by the hook.
- **So the last worker out pays that agent nothing, and its woken turn's Stop
  pays the Done.** Paying it at the exit announced Done, then Working, then Done
  again seconds later, with two banners.
- **The Stop says so**, the integration being the only place an agent is known,
  and the entry keeps it beside the Done it owes.
- **Anything the agent says ends the wait**: its tool call, its prompt, its
  Stop. A new turn, a failure or the agent going settle it like the rest.
- **A wait that nothing ends is paid after fifteen seconds**, for a wake-up that
  never comes. Cost: that Done arrives late, and the figure is a guess longer
  than a woken turn takes to call a tool or stop.
- **Shells and subagents are counted apart** wherever the workers are counted, a
  shell not being a subagent to anyone reading the label.
- **A sweep takes every dead agent before any dead shell.** An agent gone with
  its shell takes the shell with it; checked in a set's order, the shell was
  sometimes first and announced a Done for a dead agent.
- **A worker on the roster ends the wait too**, holding the Done itself, and the
  last one out starts the wait again: the woken turn's subagent can be heard
  from before its main thread, and the deadline paid a Done over it.

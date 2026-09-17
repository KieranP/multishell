# Agents

The inbound channel, each agent's hooks, and the board that shows them. Newest
at the bottom.

## Inbound channel = Unix socket + small helper

Socket, not a URL scheme, which would activate the app dozens of times a minute.
Helper, not `nc`: quoting, a stable protocol, one place for each agent's
mapping. Fields only ever added. A report naming an unknown session is dropped,
not matched by directory. One naming only a directory marks the deepest worktree
containing it: Claude Code started from `<worktree>/packages/api` says that
directory, and a worktree nested in another is the one meant.

The pid a report names is what the app polls to clear a Working the agent never
took back. From a prompt in one of the app's own tabs the helper's walk past the
shells reaches the app itself, whose pid never goes while it looks -> the app
hands each session its pid as `MULTISHELL_APP_PID`, the walk stops short of it
and names the shell underneath, whose exit clears the dot. A report naming the
app's pid anyway, from a helper older than the variable, is taken as naming
none.

Carries only what the app cannot see itself: state, pid, message, a duration so
a millisecond command posts no banner, and `agent`, a pane's agent usually being
started by hand with the tab's `agentID` nil. It moves a dot, raises a
notification, decides how a dropped file is written. Opens no tab, runs no
command, puts no text at a prompt. Shell reports run inline, else a fast
command's finished overtakes its started.

## Five agents' hooks, one hook line, one parser

Claude Code, Codex, Gemini CLI, Copilot CLI each run a command at every
lifecycle event and hand it the same three fields -> same line for all four: run
the helper, which reads the payload and maps the event that fired. What differs
is the file, what each calls an event, and how that file spells one hook = all
an `AgentHookIntegration` holds. App knows no agent by name elsewhere.

Codex has a permission request where Gemini has a notification. Claude has both
and is asked for both. Copilot is asked in the spelling whose payload names its
event, the other naming none. Gemini counts its timeout in ms, and five would
kill the helper before it reached the socket.

Copilot reads a directory of hook files, not one settings file -> its file is
ours alone: written whole, deleted to remove, no copy kept.

OpenCode reports to no command, only a plugin sees a session go idle -> given a
plugin calling the helper as any script would. Also the only agent that says a
permission was answered, allowed as well as denied -> the only pane whose
Waiting clears on the answer rather than at the next tool call. Both off the
event bus. Its `permission.ask` hook, which the plugin used to listen on, is
not: in the plugin types, uncalled since the 1.1 permissions rewrite, and the
day it is called again it would report a prompt the bus already reported. Cost:
JavaScript in the user's agent, so it spawns, unrefs and swallows everything,
and it is the one integration whose contract we do not control from a payload.

Four events narrowed, "the agent raised a notification" not being "the agent is
waiting":

- Copilot raises one when a background shell finishes as much as when it needs
  an answer -> ours asks for the two types that are questions, file filters.
- Codex has no notification, only a permission request firing before it decides
  whether anyone need answer -> under `--full-auto` every tool call would have
  posted a banner. Counts as waiting only in a mode that stops for the user; a
  mode we have not heard of is taken to stop.
- Claude's request is the same shape, narrowed the same way, its classifier mode
  being one more that answers without the user.
- Claude's notification carries fourteen types on one event and most announce
  rather than ask: a login done, a quota resumed, and the idle prompt a minute
  after a turn ends, which landed as "Waiting for input" on top of the Done that
  turn's Stop had just reported -> the four that announce are named and
  everything else counts as waiting. Sorted from the payload's
  `notification_type`, not the matcher the event does take: a matcher is written
  into the settings file, so it would reach only the installs made after the
  build that adds it, and a Claude old enough to send no type would match none
  of them and lose the banner. A deny list, so a question Claude adds later
  raises a dot instead of falling silently out; the cost the other way is that
  an announcing type added later raises one too, which is the trade taken
  deliberately.
- Claude's Stop is its main assistant loop stopping, not the turn ending: a
  subagent launched in the background outlives it, and its tool calls keep
  reporting Working afterwards -> the pane went Done, back to Working, then Done
  again, once per wave, each with a banner. So `SubagentStart` and
  `SubagentStop` are asked for too: a Stop with any outstanding is held as
  Working, and the last worker to end pays the Done the agent was owed. What is
  outstanding is a roster the app keeps, a hook being a fresh process with
  nothing to remember; see the section below. An agent that reports no workers
  never enters that arm, so Gemini keeps Stop meaning Done outright. A worker
  left on the roster costs the Done banner and nothing else, and Idle, Failed,
  the process going or the shell's own command returning clears it: the agent
  was that command, so an agent killed with a worker out, which sends no
  SubagentStop, held its pane on Working at a bare prompt until the engine's
  end-of-command was allowed to settle the roster. A worker's start and end
  carry Working, having no state worth sending, so those two are bookkeeping and
  not news: they leave a Waiting or a Failed where it is. Otherwise a background
  worker ending while a permission prompt was up withdrew the banner and moved
  the card out of Waiting, with the prompt still on screen and nothing to put it
  back. Such a tick reports nothing back to the model, `report` answering `nil`:
  it carries no message, so letting it through would have replaced the prompt's
  words on the card and posted the banner again under the same key, which on
  macOS replaces the one already there. A tool call inside a worker is not a
  tick: it is work, as the main thread's is, and the prompt a worker's tool
  raised, which names the worker too, is cleared by that worker's next call and
  not held until the main thread moves. A Waiting a worker's event carries is a
  prompt and moves the dot as one.
- Gemini needed neither: its Notification has one type, a tool permission.

Claude asked for that request beside its notification, not instead: the
notification is slower, six seconds after the prompt goes up, and dropped if the
user answers first -> alone, a prompt answered quickly never moved the dot and a
slower one moved it six seconds late. The request fires as the call reaches the
prompt, and after the call's own `PreToolUse`, so Working does not land on top.
Both timings measured from a session against this build, not read off a page.

So a prompt reports twice, only the second heard from: request moves the dot, no
banner; notification raises it. Six seconds is the agent's own rule for when a
prompt is worth interrupting someone for, and the notification carries the
wording, the request having no message at all. Without that, one prompt meant
two banners six seconds apart. `silent` is the general form: move a dot where
another report about the same thing will do the talking.

Nothing reports the answer -> dot stays blue until the next tool call or the end
of the turn: an approved call taking two minutes holds it two minutes, a prompt
escaped holds it until the next prompt. `PermissionDenied` is not the missing
half, whatever the name suggests: it fires for one thing only, a call the auto
mode's classifier turned down so a hook can appeal it, and a person refusing at
the prompt fires nothing. Taking it = a line in the user's settings for an event
that can only arrive in a mode this reports no waiting in.

Other three have nothing of the kind: Codex's request is already the immediate
one and reports no answer; Gemini's notification has one type and no
confirmation event behind it; Copilot's fires before its own rules run with a
payload that never says the mode -> under `--allow-all-tools` a banner per tool
call with nothing to narrow by, its notification already covering the prompt.
Copilot's `errorOccurred` deliberately left: carries a `recoverable` flag, and a
red dot for something the agent recovers from is worse than no red dot.

The line runs the helper rather than `exec`ing it, and exits 0 whatever became
of it: Copilot denies a tool call on any non-zero exit from a `preToolUse` hook
and Claude blocks one on exit 2 -> under `exec` a helper killed by Gatekeeper or
dying on a signal would stop the agent working rather than stop the dots moving.
Cost: one short-lived shell per event and nothing else, the pid coming from
walking past shells either way.

A settings file that is a symlink is written through, not over: an atomic write
would leave a regular file where a dotfiles repo's link was, and the user's own
copy would stop being the one the agent reads. The copy kept holds the contents
and sits beside the link, not in the repo it points into, which would leave a
file their next `git status` has to explain.

Nothing under an event is written over. Absent = an empty list to add ours to. A
string, an object, or a shape a later agent version takes = something of the
user's this cannot put back -> Add refuses and names the event, Remove steps
over it. Remove takes back what Add put in and nothing else.

That holds inside a group as well as between them. Add only ever appends a group
of its own, so a group carrying one of ours beside one of theirs was written by
hand and the theirs is not ours to drop: Remove strips our commands out of it
and leaves the group standing, taking the group whole only when nothing of the
user's is left in it. Dropping at group granularity read as Remove working, the
agent's file even shrinking, while an audit hook someone had added to our entry
went with it.

Numbers in a settings file are written back as the user spelled them. Parsed to
doubles, `0.1` came back as `0.10000000000000001` and `1.0` as `1`. Each literal
is turned into a string carrying it behind a marker before the parse and turned
back after the render, `NumberLiteral`, so nothing here reads one as a number;
nothing needs to. The marker is U+0001 and a token drawn once per process, so a
string of the user's cannot be taken for a number on the way out. Only a literal
JSON's grammar allows is marked; `01` or `1-2` is left for the parser to refuse
as before, and the bytes are decoded strictly first, a lossy decode having
written U+FFFD over a Latin-1 byte of the user's.

A settings file that will not read back as plain JSON is refused, not parsed
loosely: Gemini's takes comments and keeps them when it writes the file itself,
and a re-serialisation here would take them out. Cost: those users add the
entries by hand, so the alert names the file and points at Show JSON.

Codex will run no hook it has not been told to trust -> installing is not the
end of it and the row says so; nothing here can trust a hook for the user.

No agent is recommended, none has anything of its own outside that table. Claude
Code briefly had an install prompt with a setup link and a `curl` line, an
endorsement in a workspace built to run whichever agent the user already chose;
gone, with the property that asked about that one agent. Cost: a machine with
none installed gets an empty picker and no help filling it.

## The Agents board is a roster, not a queue

Every open pane has one card while it is open, moving between columns as its
state moves. State picks the column, never whether a card exists -> nothing is
hidden by having been looked at. A card goes when its pane closes, and in one
other case: an agent whose process has gone leaves a plain shell behind, which
the filter hides.

Failed waits with Waiting, not in Done: a failure wants the user, which is what
that column means, and it leaves Done meaning one thing. One rule about being
seen for that column, where a glance used to clear the failure and not the
question. They still part on a dead process: a question was a claim about that
process and goes with it, a failure outlived the thing that failed and stays.

The filter is the one control and decides membership alone: a shell it lets in
lands where its state says, exactly as an agent does, the zsh and bash
integration already reporting a command started and finished. So `make release`
is Working and a failed `swift test` waits, no new plumbing. No duration floor,
though NotificationPolicy has one: a banner interrupts, a card does not, and the
sidebar dot already goes green for an `ls`. On the model, not the view, because
the Dock badge counts what the Waiting column shows and must read the same flag.
Cost: off again after a relaunch.

While it is up, nothing acting on "the tab in front of the user" acts at all:
Cmd+W would end a shell in a pane nobody can see, Cmd+T open a tab appearing
only once the board is left. One `worktreeInView` answers for all of them.
Showing the board also means no pane is shown: `isShown`, `isFocused` and
`markFocusedPaneSeen` answer false, else the selected worktree's Done states
clear as it opens and their cards reach Idle having never passed through Done.

An agent's pid is polled only while the board is up, one sweep as it opens:
nowhere else shows a quit agent (a dropped file asks at the moment of the drop),
and watching always would leave a two-second timer running for as long as any
agent had ever reported. The shell's own word that its foreground command
returned drops the agent at that prompt too, the agent having been that command:
the Dock badge is read with the board closed, where no pid is polled, and a
shell's failure after its agent quit counted as an agent waiting until the board
was opened.

Four columns always drawn, empty or not: labelled columns say what the board is
for, where a page in their place says only that it is not working. Empty board
adds one line saying what would put something on it, since without a report
nothing can know an agent is at a prompt. Not gated on hooks being installed:
one agent's being in place says nothing about the agent actually at the prompt.

Ordering newest first everywhere -> an arriving card pushes the rest down a
place; nothing else about a card moves on its own. Columns share the room down
to a floor and the board scrolls past it, a partial column at the edge saying
there is more. No end arrows, which the tab strip needs because a tab scrolled
out of sight is one you forget exists; the board has four fixed columns and half
of one showing says which way the rest are. No line of output on a card: the
engine hands no scrollback to the core.

## Flags are per agent, placeholders are one list

An agent's flag line is stored against its catalogue id, not as one line for
whichever agent is chosen. Flags are written for a particular CLI, so a line
kept across a change of agent, or handed to a project that overrides the agent,
is a line the other agent will reject. Cost: switching agent and back is two
lines to fill in, and the settings row shows only the chosen agent's.

Split into words here rather than passed to the shell as text -> a branch with a
space in it stays one argument, quoted again on the way to the command line.
Quotes and backslashes group the way a shell reads them, down to a backslash
inside double quotes guarding only `"`, `\`, `$` and a backtick and standing for
itself before anything else, so a regex keeps its `\d`. Checked against zsh by
random lines over letters, spaces and the three quoting characters. A quote left
open takes the rest of the line, there being nobody to ask; an opener that
carries nothing, like a trailing backslash, passes no argument at all rather
than an empty one.

`{{branch}}` and the four beside it are one list, `AgentPlaceholder`. The two
settings rows name `{{branch}}` as an example and stop there: five of them
behind an (i) is a reference page in a tooltip, and the documentation is where
that belongs. So unlike `HookVariable`, the list is not drawn anywhere, and a
new case has to reach the docs by hand. An unknown placeholder is left as typed
-> the mistake shows in the tab rather than an argument going missing. One pass
over what was typed, so a value holding a token of its own is text: a branch
named `feat/{{project}}` used to have its own name expanded again by the
placeholders that come later in the list. `{{branch}}` on a detached worktree is
the short SHA, never blank: `--name=` reads as an error the agent reports, where
a wrong name does not.

Appended on resume too. A tab that comes back as `claude --continue` is the same
tab, and the flags said how that tab is meant to run.

A flag line is not shell text. Splitting it and quoting each word means a branch
name someone else pushed cannot run anything: `$(...)`, a backtick and a `;` all
reach the agent as literal characters. Checked against a real zsh by random
values over quotes, backslashes, `$`, a backtick, `;&|()*~!#`, a space and a
newline, on both paths: every one arrived as the one argument meant and none of
them ran. The values are not only branches, which git keeps tame, but a worktree
name the user typed and paths that are whatever the directories are called. The
same quoting is why `$HOME`, `~` and `*` in a flag line are literal too, which
is the cost: someone wanting a path there uses `{{project_path}}` or the custom
command, which is raw shell by definition. In that custom line a placeholder the
user has already wrapped in quotes (`--name="{{branch}}"`) ends up
double-quoted, its value carrying the quotes; `EditorCatalogue`'s `{path}` has
always behaved that way, and the flags field does not, having split the line
first.

Neither flags field carries prompt text. A greyed `--name={{branch}}` in an
empty field reads as what the agent is already being started with, and the
field's whole job is to say what is being passed. The custom command's own
prompt stays: there a greyed example cannot be mistaken for a command that is
running, the field being empty meaning no agent starts at all.

The project override is a line, not a table: it overrides whatever agent the
project runs. Blank is the override to no flags, the only spelling it has for
that, which makes it the fourth field where `""` is an opinion (see
settings.md). Nothing in `.multishell.json`: a flag is an argument to a program,
and a repository's file is trusted for what is drawn, not for what runs.

## Subagents are a roster by id, shown as a chip

Claude's counting events name the worker: `agent_id` and `agent_type` on
`SubagentStart` and `SubagentStop`, and the same two on every hook that fires
inside it. So what was a count is a roster, `Subagent` under each key of
`SessionStates`: a start or a first tool call puts one on, its end takes it off,
and the count is how many workers those places stand for, which is more than the
places only where an agent names two workers alike. Each carries its kind and
when it started, stamped by the model's one clock as a state is. Not the tool it
is in, though `PreToolUse` says: shown, it changed with every call and made the
list flash, and carried, it re-rendered the sidebar per call, so a tool call
from a worker already on the roster changes nothing. No task description:
nothing on the wire carries one, for any agent. The wire field is `subagent`, an
object with `id`, `type` and `phase` (`started`, `working`, `ended`); the old
`subagents` count is still read, each `1` as an unnamed worker and each `-1`
taking the last of those, because the helper link is shared between builds and
points at whichever launched last, so an older helper meets a newer app on a
developer's machine. The same link makes the reverse meeting happen too, so a
start and an end also write the count beside the object, for an app that reads
only that; a tool call writes none, or each would put another unnamed worker on
that app's roster.

Claude fires no hook on Ctrl+C, and the workers it killed send no stop, so an
interrupted fan-out left its chip standing. Nothing says "interrupted"; what
says the last turn is over is the prompt that starts the next, so
`UserPromptSubmit`, and each agent's equivalent, carries `turn` and empties the
roster, nothing owed and nothing lifted, before its own Working lands. Cost: the
chip stands from the Ctrl+C to the next prompt, however long that is; the pid
poll cannot help, the agent being alive at its prompt. And a background worker
that outlives its turn, which Claude allows, drops off the chip at the next
prompt until its own next tool call puts it back; its stop still takes it off,
so nothing is owed for it twice.

A worker out is work, the user's rule: a pane showing Done, or nothing, when a
worker starts shows Working while any is out. What the worker's report stood
over is remembered once, `displaced`, and the last worker out puts it back: a
Done is paid and announced then, so the banner still fires once and at the end,
provided the worker's start was seen: one first seen at a tool call after the
Done was announced lifts it and announces it again at its end, the app having no
way to tell a late worker from a new one; nothing is cleared again; a Failed,
which only a worker's prompt displaces and mere work leaves standing, comes back
unannounced, having been announced when it happened. The agent's own Working
takes the dot back for itself, so the last worker out then leaves it, and it
gives up that claim even where another thread's prompt holds the dot and its own
report is not news: else the last worker out puts back what the turn began over,
a Done firing in the middle of a turn the agent last said it was working
through. Its own prompt claims a Working put over nothing but not a Done it
owes. A Done the agent's Stop owes is its own kind of displaced, not the same as
one a worker stood over: hooks are separate processes over a socket, so a
main-thread event can land after the Stop it preceded, and the agent's own
Working would otherwise have thrown the owed Done away and left the pane Working
over a dead agent until the next prompt. A held Stop leaves a failure alone
either way, covered by a worker's prompt or still standing, or a failure would
be paid back as a Done; over one still standing the Stop is not even news, since
a Working would hide a failure nobody has dealt with.

A Waiting is cleared by the thread that raised it and by nothing less:
`waitingRaisers` holds each thread asking, the agent or one place on the roster,
and a thread's next tool call takes its own prompt off; the dot moves on when
none is left. Otherwise, with two workers out, the second's tool call withdrew
the first's prompt from the dot and the banner with the prompt still on screen,
and the main thread's own calls did the same to a background worker's. A worker
ending with its prompt still up, the user having denied it, takes the prompt
with it, else nothing the agent did afterwards could. The agent's Stop over a
worker's prompt is held, the Done owed, and the prompt stays until that worker
moves or ends. A failure, a new turn and the user's clear still move it, the
turn being over. Cost: a prompt whose thread never calls a tool again and never
ends, which nothing documented does, holds the dot until the turn ends. The
raiser is the roster place the report touched, not the id on the wire, because
an older helper names no worker: under the wire id every unnamed worker asked as
`""` and one end answered them all. An unnamed worker's end takes the last that
is asking before the last that is not, that being the only way an
interchangeable worker can answer its own prompt. With no unnamed place left it
takes the oldest of any kind: one worker did end, and a place left over holds
the agent's Done for the rest of the turn. A start or an end whose payload names
nobody is read as an unnamed one for the same reason, rather than as the agent's
own report. Its tool call takes the last unnamed place out rather than minting
one, which would have put another worker on the roster per call and left the
chip counting tool calls.

Per agent, from what each says to a hook. Codex spells the two events and their
fields as Claude does, feature-flagged behind `features.hooks` like the rest of
its hooks. Copilot's `subagentStart` carries `agentName` and `agentDisplayName`
and no id, its `subagentStop` an id as well -> the name is the key at both ends,
so two workers of one kind at once are one entry. That entry counts its starts
and takes as many ends, the alternative being a Done paid while the second is
still working; the chip counts those workers rather than the places, so it says
two where the list holds one row, which carries a `×2`. Nothing says which of
them a later report came from, so neither a tool call nor an end under a shared
place answers a prompt raised there while another worker is still on it: the
prompt stands until the last one out, the alternative being the second worker
withdrawing the first's prompt from the dot and the banner with it still on
screen. Cost: a prompt the asking worker answered stays until its sibling's next
report, one worker short of shared. A duplicate start, which no agent documents,
would hold the roster place until the turn ends. Its built-in `general-purpose`
emits neither. Gemini names a subagent to its telemetry and never to a hook, so
its rows show none. OpenCode runs a subagent as a child session: its plugin
takes `session.created` with `parentID` as a start, the child's own
`session.status` busy and `tool.execute.before` as tool calls, its
`session.idle` or `session.error` as the end, and reports them through
`state --subagent`; a child's idle is not the pane's Done. `session.idle` is
deprecated in favour of `session.status`, so both spellings end a child and both
are the parent's Done: reading only the old one in the parent would have left
the pane Working for good once OpenCode drops it. An ended child's id is kept,
its entry marked rather than deleted, so a second end or a late permission of
its own is not read as the parent's; a busy status is the one thing that puts it
back, and the oldest ended ids go once the list is over 64, rather than one per
subagent for the life of the process. Ended ids are kept in their own list,
oldest first, and the cap is on that list rather than on the map: gated on the
map a child going busy and idle over and over grew the list without bound, the
map never crossing 64. One place per child there, so those cycles neither grow
the list nor push other children out of it, at the price of a scan of at most 64
ids per end; a child busy again keeps its place until its next end. Where the
roster has to be pieced together from what an agent reports, and the pieces
disagree, the pane's dot is what the pieces agree on: a report for a worker not
on the roster puts it on, an end for one never seen takes nothing, and the
roster is cleared with everything else that clears.

Drawn as a chip in the Working colour, the count behind a branch glyph, on a
pane's row in the sidebar and on its board card while that pane has a worker
out, and on neither when it has none: an empty chip would be one more badge on
every row. Not on the worktree row, which was tried: the row already carries
four badges, and the pane rows under the selected worktree say which pane the
swarm is in, where a count on the worktree could not. A report naming only a
directory, from a terminal outside the app, keeps its workers under the
worktree's own key, which moves the worktree's dot and shows on no chip, there
being no pane to hang one on. Hovering the chip lists them, kind and time, in a
popover that ticks while it is up; nothing else grows, so a fan-out of eight
costs the sidebar no rows and the board no height. Chosen over rows under the
tab, which an eight-agent fan-out would have pushed the next project off screen
with, and over cards of their own, which broke one card per pane and counted
things nothing could open. Cost: the list is never on screen unless the pointer
is on a 20-point target, and VoiceOver gets it as the chip's label rather than
as rows.

## The selected worktree lists its panes in the sidebar

Under the selected worktree's row, one row per pane, `PaneRows`, a split tab
giving one per pane rather than one for the tab: the pane's own dot, its own
title, and a subagent chip of its own while it has workers out, so a glance down
the sidebar says which pane of the worktree is working, which is done and which
has a swarm, without reading the strip. A tab was the row first, and a split's
second pane, which has its own agent and its own dot, was nowhere. A split's
panes carry a split glyph and their position, since a renamed tab names every
pane alike and two plain shells both read as the shell. That row drops its
terminal count, the rows under it being the count. The active tab's focused pane
is bold, one per worktree and not one per column: with two columns two tabs are
on screen, and two bold rows read as two selections. A click shows another and
hands it the keyboard, the way a board card does. Only the selected worktree's,
so one set takes room at a time and a project with forty panes across its
worktrees does not become forty rows. Each row is `paneRowHeight`, which the
sidebar's block height counts off as it counts a named row, or the drop
indicator lands in the wrong half. Cost: selecting a worktree shifts every row
under it by its pane count.

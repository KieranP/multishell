# Agents

The inbound channel, each agent's hooks, and the board that shows them.
Newest at the bottom.

## Inbound channel = Unix socket + small helper

Socket, not a URL scheme, which would activate the app dozens of times a
minute. Helper, not `nc`: quoting, a stable protocol, one place for each
agent's mapping. Fields only ever added. A report naming an unknown session is
dropped, not matched by directory.

Carries only what the app cannot see itself: state, pid, message, a duration so
a millisecond command posts no banner, and `agent`, a pane's agent usually
being started by hand with the tab's `agentID` nil. It moves a dot, raises a
notification, decides how a dropped file is written. Opens no tab, runs no
command, puts no text at a prompt. Shell reports run inline, else a fast
command's finished overtakes its started.

## Five agents' hooks, one hook line, one parser

Claude Code, Codex, Gemini CLI, Copilot CLI each run a command at every
lifecycle event and hand it the same three fields -> same line for all four:
run the helper, which reads the payload and maps the event that fired. What
differs is the file, what each calls an event, and how that file spells one
hook = all an `AgentHookIntegration` holds. App knows no agent by name
elsewhere.

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

Four events narrowed, "the agent raised a notification" not being "the agent
is waiting":
- Copilot raises one when a background shell finishes as much as when it needs
  an answer -> ours asks for the two types that are questions, file filters.
- Codex has no notification, only a permission request firing before it decides
  whether anyone need answer -> under `--full-auto` every tool call would have
  posted a banner. Counts as waiting only in a mode that stops for the user; a
  mode we have not heard of is taken to stop.
- Claude's request is the same shape, narrowed the same way, its classifier
  mode being one more that answers without the user.
- Claude's notification carries fourteen types on one event and most announce
  rather than ask: a login done, a quota resumed, and the idle prompt a minute
  after a turn ends, which landed as "Waiting for input" on top of the Done
  that turn's Stop had just reported -> the four that announce are named and
  everything else counts as waiting. Sorted from the payload's
  `notification_type`, not the matcher the event does take: a matcher is
  written into the settings file, so it would reach only the installs made
  after the build that adds it, and a Claude old enough to send no type would
  match none of them and lose the banner. A deny list, so a question Claude
  adds later raises a dot instead of falling silently out; the cost the other
  way is that an announcing type added later raises one too, which is the
  trade taken deliberately.
- Gemini needed neither: its Notification has one type, a tool permission.

Claude asked for that request beside its notification, not instead: the
notification is slower, six seconds after the prompt goes up, and dropped if
the user answers first -> alone, a prompt answered quickly never moved the dot
and a slower one moved it six seconds late. The request fires as the call
reaches the prompt, and after the call's own `PreToolUse`, so Working does not
land on top. Both timings measured from a session against this build, not read
off a page.

So a prompt reports twice, only the second heard from: request moves the dot,
no banner; notification raises it. Six seconds is as good a rule as any for
when a prompt is worth interrupting someone for, it is the agent's own rule,
and the notification carries the wording, the request having no message at all.
Without that, one prompt meant two banners six seconds apart. `silent` is the
general form: move a dot where another report about the same thing will do the
talking.

Nothing reports the answer -> dot stays blue until the next tool call or the
end of the turn: an approved call taking two minutes holds it two minutes, a
prompt escaped holds it until the next prompt. `PermissionDenied` is not the
missing half, whatever the name suggests: it fires for one thing only, a call
the auto mode's classifier turned down so a hook can appeal it, and a person
refusing at the prompt fires nothing. Taking it = a line in the user's settings
for an event that can only arrive in a mode this reports no waiting in.

Other three have nothing of the kind: Codex's request is already the immediate
one and reports no answer; Gemini's notification has one type and no
confirmation event behind it; Copilot's fires before its own rules run with a
payload that never says the mode -> under `--allow-all-tools` a banner per tool
call with nothing to narrow by, its notification already covering the prompt.
Copilot's `errorOccurred` deliberately left: carries a `recoverable` flag, and
a red dot for something the agent recovers from is worse than no red dot.

The line runs the helper rather than `exec`ing it, and exits 0 whatever became
of it: Copilot denies a tool call on any non-zero exit from a `preToolUse` hook
and Claude blocks one on exit 2 -> under `exec` a helper killed by Gatekeeper
or dying on a signal would stop the agent working rather than stop the dots
moving. Cost: one short-lived shell per event and nothing else, the pid coming
from walking past shells either way.

A settings file that is a symlink is written through, not over: an atomic write
would leave a regular file where a dotfiles repo's link was, and the user's own
copy would stop being the one the agent reads. The copy kept holds the contents
and sits beside the link, not in the repo it points into, which would leave a
file their next `git status` has to explain.

Nothing under an event is written over. Absent = an empty list to add ours to.
A string, an object, or a shape a later agent version takes = something of the
user's this cannot put back -> Add refuses and names the event, Remove steps
over it. Remove takes back what Add put in and nothing else, the whole of what
it promises.

That holds inside a group as well as between them. Add only ever appends a
group of its own, so a group carrying one of ours beside one of theirs was
written by hand and the theirs is not ours to drop: Remove strips our commands
out of it and leaves the group standing, taking the group whole only when
nothing of the user's is left in it. Dropping at group granularity read as
Remove working, the agent's file even shrinking, while an audit hook someone
had added to our entry went with it.

A settings file that will not read back as plain JSON is refused, not parsed
loosely: Gemini's takes comments and keeps them when it writes the file itself,
and a re-serialisation here would take them out. Cost: those users add the
entries by hand, so the alert names the file and points at Show JSON.

Codex will run no hook it has not been told to trust -> installing is not the
end of it and the row says so; nothing here can trust a hook for the user.

No agent is recommended, none has anything of its own outside that table.
Claude Code briefly had an install prompt with a setup link and a `curl` line,
an endorsement in a workspace built to run whichever agent the user already
chose; gone, with the property that asked about that one agent. Cost: a machine
with none installed gets an empty picker and no help filling it.

## The Agents board is a roster, not a queue

Every open pane has one card while it is open, moving between columns as its
state moves. State picks the column, never whether a card exists -> nothing is
hidden by having been looked at. A card goes when its pane closes, and in one
other case: an agent whose process has gone leaves a plain shell behind, which
the filter hides.

Failed waits with Waiting, not in Done: a failure wants the user, which is what
that column means, and it leaves Done meaning one thing. One rule about being seen in
that column now, where a glance used to clear the failure and not the
question and the cards sat under two for no reason either could state. They
still part on a dead process: a question was a claim about that process and
goes with it, a failure outlived the thing that failed and stays.

The filter is the one control and decides membership alone: a shell it lets in
lands where its state says, exactly as an agent does, the zsh and bash
integration already reporting a command started and finished. So `make release`
is Working and a failed `swift test` waits, no new plumbing. No duration floor,
though NotificationPolicy has one: a banner interrupts, a card does not, and
the sidebar dot already goes green for an `ls`. On the model, not the view,
because the Dock badge counts what the Waiting column shows and must read the
same flag. Cost: off again after a relaunch.

While it is up, nothing acting on "the tab in front of the user" acts at all:
Cmd+W would end a shell in a pane nobody can see, Cmd+T open a tab appearing
only once the board is left. One `worktreeInView` answers for all of them.
Showing the board also means no pane is shown: `isShown` and
`markShownTabSeen` answer false, else the selected worktree's Done states
clear as it opens and their cards reach Idle having never passed
through Done.

An agent's pid is polled only while the board is up, one sweep as it opens:
nowhere else shows a quit agent (a dropped file asks at the moment of the
drop), and watching always would leave a two-second timer running for as long
as any agent had ever reported.

Four columns always drawn, empty or not: labelled columns say what the board is
for, where a page in their place says only that it is not working. Empty board
adds one line saying what would put something on it, since without a report
nothing can know an agent is at a prompt. Not gated on hooks being installed:
one agent's being in place says nothing about the agent actually at the prompt.

Ordering newest first everywhere -> an arriving card pushes the rest down a
place; nothing else about a card moves on its own. Columns share the room down
to a floor and the board scrolls past it, a partial column at the edge saying
there is more. No end arrows, which the tab strip needs because a tab scrolled
out of sight is one you forget exists; the board has four fixed columns and
half of one showing says which way the rest are. No line of output on a card:
neither engine hands scrollback to the core.

## Flags are per agent, placeholders are one list

An agent's flag line is stored against its catalogue id, not as one line for
whichever agent is chosen. Flags are written for a particular CLI, so a line
kept across a change of agent, or handed to a project that overrides the agent,
is a line the other agent will reject. Cost: switching agent and back is two
lines to fill in, and the settings row shows only the chosen agent's.

Split into words here rather than passed to the shell as text -> a branch with
a space in it stays one argument, quoted again on the way to the command line.
Quotes and backslashes group the way a shell reads them, down to a backslash
inside double quotes guarding only `"`, `\`, `$` and a backtick and standing
for itself before anything else, so a regex keeps its `\d`. Checked against
zsh by random lines over letters, spaces and the three quoting characters. A
quote left open takes the rest of the line, there being nobody to ask; an
opener that carries nothing, like a trailing backslash, passes no argument at
all rather than an empty one.

`{{branch}}` and the four beside it are one list, `AgentPlaceholder`. The two
settings rows name `{{branch}}` as an example and stop there: five of them
behind an (i) is a reference page in a tooltip, and the documentation is where
that belongs. So unlike `HookVariable`, the list is not drawn anywhere, and a
new case has to reach the docs by hand. An unknown placeholder is left as typed
-> the mistake shows in the tab rather than an argument going missing.
`{{branch}}` on a detached worktree is the short SHA, never blank: `--name=`
reads as an error the agent reports, where a wrong name does not.

Appended on resume too. A tab that comes back as `claude --continue` is the
same tab, and the flags said how that tab is meant to run.

A flag line is not shell text. Splitting it and quoting each word means a
branch name someone else pushed cannot run anything: `$(...)`, a backtick and a
`;` all reach the agent as literal characters. Checked against a real zsh by
random values over quotes, backslashes, `$`, a backtick, `;&|()*~!#`, a space
and a newline, on both paths: every one arrived as the one argument meant and
none of them ran. The values are not only branches, which git keeps tame, but a
worktree name the user typed and paths that are whatever the directories are
called. The
same quoting is why `$HOME`, `~` and `*` in a flag line are literal too, which
is the cost: someone wanting a path there uses `{{project_path}}` or the custom
command, which is raw shell by definition. In that custom line a placeholder
the user has already wrapped in quotes (`--name="{{branch}}"`) ends up
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
settings.md). Nothing in `.multishell.json`: a flag is an argument to a
program, and a repository's file is trusted for what is drawn, not for what
runs.

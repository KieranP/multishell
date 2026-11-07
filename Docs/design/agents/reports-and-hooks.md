# Reports and each agent's hooks

The inbound channel, each agent's hooks and what Add and Remove write to a
user's settings file. Newest at the bottom.

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
  a command-line request may do all three (agents/command-line.md).
- **Shell reports never go in the background**, or a fast command's finished
  overtakes its started (terminals/shell-integration.md).
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
  permission prompt. Antigravity says waiting through OSC 7501 once the terminal
  answers its check, which patch 0007 does, and its own reports then decide the
  dot (agents/program-status.md); read from 1.5.3's binary.
- **Each model call is a turn start**, PreInvocation firing per call with no
  sign of the user's prompt bar `invocationNum`. Antigravity has no worker the
  roster counts, so a start mid-turn clears nothing.
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

- **Antigravity's directory is the first of `workspacePaths`, over the tab's
  worktree** (round 3): a report from a tab names its session, which decides the
  pane; the directory places only one naming none, and Antigravity lists the
  workspace it started in first.
- **A named set's `enabled` handled in `hooksObject`, `isLeftEmpty` and
  `replacingOurs`** (round 3): round 2 put the restore in one line of
  `replacingOurs`; moving the drop from `removing` to Remove is another shape
  for the same behaviour, which is tested, so it stays.
- **A switched-off Antigravity set still reads as current in Settings** (round
  5): Update keeps the switch as the user left it, and a state of its own for a
  switched-off set is a feature, not a fix.
- **An Antigravity payload that is not a JSON object reports nothing** (round
  7): the probe of 1.4.8 saw an object on every event, and a report made up from
  the hook line alone would be a guess.
- **Antigravity's Stop `fullyIdle` is not read** (round 8): the probe saw it
  true on every Stop, and what false would mean is unread, so a Stop is Done by
  its reason alone.
- **`ourGroup` deciding a named set's entry shape beside the format switches**
  (round 15): it is the one place both the write and the merge take an entry's
  shape from, so the merge cannot write a shape the write does not.
- **Other Antigravity products firing our hooks** (round 17): unread whether any
  read `~/.gemini/config/hooks.json`; a run outside a pane reports by directory,
  as every agent's does.

### Asked both ways

- **Antigravity's Stop listed three times under reported names, and
  `hooksObject` writing each name once**: round 4 asked for the write-once skip
  so the last of three identical entries did not silently win; round 5 asked to
  drop the three entries for one Stop whose state follows the payload's reason.
  Kept round 4's: every event keeps one state, as the other agents' do, and the
  skip is tested by every install test.
- **`hookLineNamesEvent` as a switch or `self == .antigravity`**: round 1 wrote
  the comparison, round 12 asked for a switch so a new spelling must answer, and
  round 18 asked for the comparison again. Kept round 12's switch.

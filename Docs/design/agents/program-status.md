# Program status over OSC 7501

What a program says of itself through OSC 7501, the program status protocol, and
how it decides a pane's dot. Newest at the bottom.

- **A program's own report beats a hook's reading of it.** Claude Code 2.1.295
  and Codex 0.167 report working, waiting, done and failed themselves, from the
  state they draw; the hooks reconstruct it from events, and the background-work
  rules exist to undo what that reconstruction gets wrong.
- **Hooks still list the workers.** Claude's child records carry an id and a
  title only: no kind, no parent, no shell flag, no kill. Codex sends none. So
  while a pane's program holds the dot, an agent's hook reports keep the roster
  and move nothing else
  (`anAgentsHookUnderAProgramsStatusListsItsWorkersAndMovesNoDot`).
- **Libghostty reads the protocol; the app surfaces dropped it**, so patch 0007
  passes each report on as an action and answers the `?` query
  (develop/dependencies.md). Claude asks first and reports nothing without the
  answer; Codex reports to any terminal outside an old VTE.
- **The query is answered with Ghostty's own reply**, the states and kinds its
  parser accepts, so a program asking for one Ghostty drops falls back as the
  specification says.
- **A pane holds the program's records**: its own, and its children by id. A
  report replaces its record; a clear takes the record and everything under it,
  and a clear with no id takes all of them.
- **The hold lasts from the first report that keeps a record to the program's
  own clear.** A child's finish or clear leaving no record is not the program
  leaving: read as one, a deploy reporting only per region lost its Working
  while it ran.
- **A program known only by its children is at work while it holds**, as a
  foreground command is: left where its last child put it, a dot stayed Waiting
  after the question was answered.
- **The dot is the most urgent record**, a blocked child above a working one,
  either above the program's own finish. Claude ends its turn Done with
  background tasks still listed, so the Done waits for the last child out, as a
  Stop's waits for the last worker.
- **Claude writes its own record before its children's in one write**, so a
  woken turn's Working lands before the finished task's clear.
- **A child's own Done or Failed moves nothing**: the program's own record says
  how the whole ended. Claude sends its children only as working or blocked.
- **So only a working or asking child takes a place**, the 64 the roster holds;
  one reported finished goes. Kept, finished children a program never cleared
  filled the places, and a later question was dropped.
- **Only a change of the dot is news.** Claude rewords its Working as the task
  summary moves; a report that keeps the state raises no banner and no note.
- **The records keep states, not words**, save the program's own finish: stored
  whole, each reword changed the observed states and redrew every view reading
  them. A dot moving to Working or Waiting takes the words of a report of that
  state, and none from a clear or a child's own finish.
- **A Done the user saw stays cleared** while the program keeps repeating it:
  the comparison is with the records' last state, not the dot.
- **What ends the hold**: the program's own clear, the shell's own report of a
  command, the command finishing, the process going, the user's Clear. Each
  hands the dot back to whatever reports next; kept past the user's Clear, a
  program gone without a word muted the hooks for good.
- **A clear is a process going**: Working, Waiting, the hooks' workers and the
  pid go, a finish stays, the clear coming at the program's exit.
- **The pid is the session's foreground process when the report lands**, which
  is the agent for one typed at a prompt and for one the app launched, each in
  its own process group. The poll uses it as it uses a hook's pid, and polls it
  for as long as the hold lasts: a Done or an Idle drops a state's pid, and a
  program killed there would otherwise hold the dot for good. Cost: the poll
  runs while any program holds a dot, one signal check per program each pass.
- **The program's own record's `app` names the agent at the prompt** where the
  catalogue knows the name: `claude-code` and `codex`. A child record's `app`
  and a clear name nothing, a child being free to name another program.
- **The agent at the prompt is read from the hold first**, the hooks' agent map
  after it. Copied into that map, it needed a write wherever a hold ends, and an
  agent the program ran from its tool shell re-pointed it.
- **The hold's agent is decided once and kept for the hold**: its own `app`
  where the catalogue knows it, else the agent a hook named before the hold
  began, else the first a hook names during the hold. Worked out again at each
  report, a report naming no `app` mid-hold took Claude for a command, and an
  agent a deploy tool ran became the tool.
- **A program the catalogue does not know is the agent its hooks name**, as
  Antigravity, whose `app` is not read from its binary: taken for a command, its
  hooks would have been muted, its turns timed and its questions worded as a
  command's. The hooks' agent is kept with the pid it gave, a report with none
  keeping it, and a sweep that finds the pid gone forgets the name; it is not
  polled for that, a quiet agent being watched only while the board is up. Its
  own clear takes the agent off the prompt, a pane with no shell integration
  having no other sign.
- **An agent the program ran from its own tool shell is nested**: another agent
  than the hold's. Its hooks move nothing, the roster included: its Stop's list
  rewrote the holder's workers, and its name and directory took the holder's.
  Told apart by the agent alone: a hook's pid is the agent's process and the
  hold's its process group's leader, which for npm's Codex, `caffeinate claude`
  or `op run` is a wrapper, so a pid test took the agent's own hooks for a
  nested one's.
- **The hold keeps the first pid it was given**: a report can land while a child
  of the program is in front, whose exit is not the program's.
- **A finish with no work before it took no time**: timed from the work before
  the last Idle, a quick Done raised a banner for minutes it never spent.
- **Any other program works as a command does**: its Working asks nothing at a
  close or a quit, and its finish is timed from when its work began, through any
  question it asked, so a quick one raises no banner. Where the shell reported
  the command first, its start is when the work began: a program reporting only
  its Done was otherwise never timed, and its shell's timed Done was muted as
  announced. An agent's turn is not timed, as its hooks' never were.
- **A question a command leaves unworded keeps the plain Waiting wording**: the
  catalogue's words name an agent.
- **Codex turns its Done and Failed to Idle at the user's next key, paste or
  click.** That clears a Failed the user typed into, which is the source
  reporting again.
- **Banners take the program's message**, its permission text or turn summary. A
  question it leaves unworded is worded from the catalogue, as a hook's is.
- **Claude marks turns with OSC 133 only in its screen-reader mode.** There a
  turn's end is a finished command to Ghostty and ends the hold until the next
  report; read from 2.1.319's binary.
- **A Waiting raises its banner as the report lands.** Under hooks Claude's
  banner came from its notification six seconds after the prompt, and a prompt
  answered sooner raised none; the program's report is the prompt itself and has
  no such delay. Cost: a background pane's quick prompt banners, then withdraws
  it when the state moves.
- **A program's Done waits while the hooks list work out**
  (agents/background-work.md): Claude 2.1.319 reports Done as its turn ends with
  a backgrounded shell still running, which it lists as no child record, and
  drops a running subagent's record before the subagent ends. Seen in a debug
  build's log, each such turn announced Done twice. So the dot stays Working
  while the roster holds work. The program's next Done pays it where a worker's
  end wakes it, as Claude's do; otherwise the last one out pays it, with the
  program's words: a cancelled worker, a Stop's list ending the work, or Codex,
  which takes no turn for its workers. A Done held so was never shown, so the
  command's end and the shell's report land it rather than repeat it. A worker
  heard after the program's Done landed puts the dot back to Working, its banner
  withdrawn, as a Stop's worker heard late does.
- **A full reset sends a clear to every pane**, so a clear in a pane no program
  holds moves nothing: `tsc --watch` resets the terminal on every rebuild, and
  took the shell's Working with it.
- **Engine activity leaves a held dot alone**: the program said what it is
  doing, and a title change painted Done over its idle.
- **The command's end and the shell's report after a program's finish are no
  news**, whichever comes first: the hold's end keeps the finish it announced
  for each, and each spends its own. A Done repeats any finish and a Failed
  repeats a Failed; a failing exit after a Done still lands its Failed, and a
  Done the user saw stays cleared. Work starting spends what is left, a hook's
  or the next command's, and so does a later command's end, so over ssh, with no
  report from the shell, the next command's end is news again. A hook's Idle, or
  a late Stop repeating the finish, after the program left is no news: Claude's
  session end can land after its clear.
- **A report with no pid takes the pid the hooks' agent gave**, or the poll
  could never see the program go; never the shell's own, which outlives it. The
  poll ending a hold takes the hold's agent off the prompt with its directory, a
  wrapper's pid having stood for it.
- **The agent's directory goes wherever the agent leaves the prompt**: the
  command's end, the program's clear, the poll. Kept, a pane's next agent with
  no hooks to name one was handed the last one's for drops. It stays a map of
  its own, unobserved, a hook's directory moving often.
- **Patch 0007 passes every key the parser reads**, `progress` and `title`
  included, though the app reads neither yet: a feature that wants them then
  needs no new cut of the patch and no libghostty rebuild to try.

## Reviewed and left as is

- **The pid is read when the main thread handles the report** (round 1), not
  when the program wrote it: the surface hands it over through a mailbox, and a
  report raced by the program's own exit names the shell for one report, which
  the next report, the command's end or the poll puts right.
- **`GhosttySurfaceEvent`'s decoding moved into a static function** (round 1):
  one more case put the initialiser over SwiftLint's complexity limit.
- **A nested interactive zsh's exit report ending the hold** (round 1): unread
  whether an agent starts one that loads our integration; hooks had the same
  exposure, and the program's next change of state takes the dot back.
- **The user's Clear lets a live program's next Done land** (round 2): Clear is
  for a program gone without a word, and one still running that reports again is
  news. Claude repeats a Done only when its words change.
- **The shell's socket report overtaking the program's last OSC 7501 report**
  (round 2): unproven; the program writes its report to the pty before it exits
  and before the shell's precmd runs, and Ghostty reads the pty as it arrives.
- **A full reset during a hold settles the hooks' roster** (round 3): it sends
  the same clear as the program's exit, which must settle it; a program that
  survives its own terminal's reset reports again and the hooks list again.
- **A background job's OSC 7501 report takes the hold** (round 5): nothing in
  the embedding API says which job wrote to the pty, and the shell's own report
  of the next command ends the hold. Trace only; no agent backgrounds itself.
- **Claude's screen-reader mode loses its directory at each turn's end** (round
  7): there a turn's end is a command's, which takes the agent off; its next
  hook report names the directory again.
- **A reworded report runs a whole `mutateStates`** (round 7): a copy, a stamp
  pass and a compare over the panes, every few seconds, fewer than the hook
  events it stands in for.
- **The program's exit clear after the user's Clear leaves its hooks' agent**
  (round 10): the Clear ended the hold, so the clear finds none to end. It needs
  a pane with no shell integration and the board closed as well.
- **A remembered finish muting the ssh session's own Done** (round 10): only
  where the program's command was the last the remote shell ran before the user
  left; any later remote command's end spends it.
- **An agent of the same kind run inside the holder counts as the holder**
  (round 15): its hooks list workers and may rewrite the roster at its Stop.
  Hooks alone had the same exposure, and only the agent tells nesting apart.
- **A session-end hook after the program's clear names the agent again** (round
  15): an unknown program's next hold in that pane adopts the name. It needs no
  shell integration, the board closed and such a program next.
- **The hooks' agent kept by the states and by the model** (round 15): the
  states are a value with no model to read; the model's map is for the board and
  drops, the states' for a hold whose `app` names no agent.
- **`isNestedAgent` asked twice per hook** (round 15): one function, so the
  model and the states cannot disagree, and a dictionary lookup each.
- **An unknown program's hold takes the first agent a hook names during it**
  (round 16): an agent the program runs before its own hooks speak is taken for
  it. A pid cannot tell the program's own hook from a nested one's.
- **A one-shot program that reports and exits before its report is handled holds
  the shell's pid** (round 18): the embedding API gives no way to tell the
  pane's shell from its foreground program, and the hold is ended by the shell's
  own report or command end wherever the shell has our integration.
- **A hold ended through the hook's pid leaves its agent at the prompt** (round
  19): not so. That pid is the one the hooks' agent map carries, and the sweep
  forgets every agent reported under a gone pid.
- **`forgetReportedAgent(in:ifItIs:)` returns whether one went** (round 19): the
  badge update it gates walks every session, once per gone pid otherwise.
- **A held Done has its own last-worker-out path beside the hooks' owed Done**
  (round 20): the program's Done lives in its records, which its next report
  rewrites, and its wake is that report; folded into the stored owed Done, both
  would need undoing at every report. No input yet makes the two disagree.

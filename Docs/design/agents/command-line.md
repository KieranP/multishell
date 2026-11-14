# The command line's requests

The command line's requests on the reports' socket. Newest at the bottom.

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
- **`tabs list` and `tabs show` include file tabs**, `kind` saying which. Cost:
  a script reading panes off every tab filters on `kind` first.
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
- **What a row or a tab shows is listed from the calls its views make**
  (`sidebar list`, `board list`, `tabs show`), so a test reads the values the
  screen draws, not a copy.
- **Every command naming a pane's agent names the one at its prompt**, as its
  mark does. Reading the agent the tab was opened as, `panes show` and
  `tabs list` missed a `claude` typed into a shell tab that `sidebar list` and
  `board list` showed (`aPaneNamesTheAgentAtItsPromptAsTheSidebarAndBoardDo`).
- **`worktrees show` reads git before it answers**, since status is read only
  while the app is frontmost, the Files panel's worktree aside
  (worktrees/watching-and-status-reads.md), and a scripted copy usually is not.
- **The settings window opens through SwiftUI's own opener**, which only a view
  can reach, so the root view hands it to the platform. AppKit cannot open a
  SwiftUI scene, and closing one goes by the window's identifier. `--page` turns
  it as the sidebar's row would, `agents` on All Projects to its first part, and
  a page the scope lacks is refused naming the scope's own. The page and its
  scope go in one request, so a refusal moves nothing.
- **`tabs open-file` opens a file by the Files panel click's rule**, so a file
  that would open neither as text nor as an image is refused where the click
  beeps. In a worktree out of view it opens without switching to it, as
  `tabs open` does.
- **`tabs find` answers with its count**, unlike `panes find`, whose engine
  counts later: the app answers only once the tab's rows are in hand, and a file
  is searched as it is asked.
- **A file tab's arrows and find need the tab on screen.** A hidden tab lets its
  rows go, and its view is what steps, so a step would wait for a show and a
  count would be of nothing; the refusal names `tabs select`. A step the view
  last said its arrow cannot take is refused; one it can is queued and answered
  at once, the view taking it on its next update. Rows not yet in hand, the
  tab's read waited on or another read running, refuse a step or find as not
  read, and the helper asks again for five seconds, each ask given the usual
  thirty: an ask cut short may still act in the app, and asking again would act
  twice. A tab under a worktree's operation is refused as that worktree not
  ready, as `tabs select` would not bring it back.
- **`files` acts on the panel on screen and names no worktree.** Its list is
  read only while it shows, so another worktree's would be of nothing read.
- **`review` takes `--worktree`, the one in view where none is named**: its
  comments are kept on disk whatever the panel shows. `review add` still needs
  the file's tab shown, its quote coming from the tab's rows
  (files/review-comments.md).
- **`ui switcher` opens the quick switcher without Cmd+P's key-window check**: a
  request comes from no window. The check stays on the keys. Cost: over a window
  that is not key, its field has no keyboard until a click.
- **`ui show pull-request` and `ci` go through the glyph click's call**, and are
  refused where the row draws no such glyph, as there is nothing to click. They
  take no `ui hide`: the panel's own toggle shuts it.
- **A request drawn in the main window asks that it is open, not on screen**:
  the switcher and a panel page draw behind another window or in a minimized
  one, shown once it is back. `tabs step`, `tabs find`, `files` and `review add`
  also refuse a covered or minimized window, which reads no file tab or panel
  list (files/file-tabs.md, files/panel.md), though `tabs find --close` shuts a
  bar anyway; `window size` and `full-screen` refuse a minimized one. A tab
  drawn as a notice, its file too large, binary, missing or unreadable, or as an
  image, takes no step or find, having no arrows or bar, and is refused as not
  read while a read of it runs, which may bring rows; an image's refusal says
  image rather than notice. A file with no changes draws no arrows either. A
  request's own words are checked before the window, so a bad one is named.
- **`worktrees hide` refuses the project's own checkout, and
  `projects expand-hidden` a project hiding none**: the menu has no Hide item
  for the one, and the sidebar no Hidden row for the other.
- **Moves and resizes go through the calls the drags make.** A share count that
  does not match the split or the groups is refused, where the tree's own guard
  would quietly keep the old shares, and so is a share leaving a pane narrower
  than a drag would. That length is known only on screen, from the panes'
  frames. Cost: shares for a tab out of view, or groups beside a file tab, are
  taken unchecked.
- **A panel's width is written where the views read it**, a debug build's own
  user defaults (develop/state-on-disk.md), so a scratch run never moves the
  installed app's edges. A width past what a drag reaches is refused: each
  side's reach is half the room the other side leaves, as its drag's is, so with
  no window open there is nothing to measure and it is refused.
- **Fetch and Refresh answer once done; Auto Rename once started.** A script
  waits on the first two's reads; a rename runs an agent for seconds, and
  `sidebar list` says while it runs and how it ended.
- **`worktrees add` with no PROJECT_ID makes it in the project holding the
  folder it runs in**, found as `projects add` finds one, through a subfolder or
  a linked worktree, and refused where none holds it rather than adding one.
  Narrowed 2026-11-14 from ids only, so a shell function can make a worktree for
  a ticket from inside the repository. No typed path names a project; the id
  stays the only name.
- **`worktrees add --background` makes the worktree without selecting it**, its
  first tab starting out of view as a held-back one does after its hook, and the
  keyboard staying put. Added 2026-11-14 so a script can make several at once
  without each pulling the view to itself.

## Reviewed and left as is

### Asked both ways

- **The helper's parse helpers sit beside the command they parse**, `tabMove`,
  `switcherOrder` and `removalOrder` as `tabOrder` and `worktreeOrder` always
  have, each private to its command's file.
- **`projects fetch` and `refresh` run on after the helper hangs up**, as the
  menu's Fetch and Refresh do: neither holds a stopper to stop, and a fetch left
  to finish only brings the remote's refs up to date.
- **`reachTerminalTab` throws the tab it reached, `refusalToReachFileTab`
  returns only a refusal**: the terminal tab's callers use the tab, the file
  tab's use none, and a throw needs no `?? .noTab` that cannot run.
- **`ui show pull-request` and `ci` send `showServicePage`, not `showView`**:
  `showView` names a project, the only other view taking an id, and a page is a
  worktree's.
- **`ui show pull-request` and `ci` test the row's glyphs as `ciRun` and
  `shownPullRequest` being set**, the values the glyphs draw: the view needs
  each value to draw it, so a shared Bool would sit beside an unwrap anyway.
- **A hidden app's window counted as closed.** Unproven: AppKit may say a window
  of an app hidden with Cmd+H is not visible, which would refuse requests
  needing it open as `noWindow`; not run, as hiding needs the desktop.
- **A step or find under another read of the tab is refused for the helper to
  ask again**, not waited on in the app: the read log holds no waiter, and one
  would need resuming on a close as well as a finish. Cost: up to fifty asks in
  the five seconds, and a read landing later is reported as still reading.
- **`FileTabContent.drawsNoRows` and `FileTabNoticeText.message` each switch
  over the content**, asked for both ways: one shared test built a localized
  string per request, and a separate notice type is more than two short switches
  need.
- **`tabs find --close` ends a find kept over a tab drawn as a notice**, though
  `tabs show` lists no bar there: the find would come back with the rows, and a
  refusal would leave no way to drop it.
- **A negative number before the options is a word for every command**, not only
  for shares: no option is spelled as a number, so `panes type P -1` types it
  rather than refusing an option that cannot exist.

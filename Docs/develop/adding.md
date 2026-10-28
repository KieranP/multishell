# Adding a thing

What each addition needs beyond the code itself.

- **A theme.** A `.json` in the themes folder; the examples beside it list every
  key, and anything a theme leaves out is its base theme's.
- **A built-in theme** is a complete JSON file in Core's `Resources/themes`,
  named in `Theme.builtins` and in ThemeBuiltinsTests' list of ids, the suite
  that holds it to every key. A port of someone's palette also takes a row in
  `THIRD-PARTY-NOTICES.md` and its licence in `Licenses/Themes/`.
- **A new colour** is a key in its section's enum, in
  `InterfaceSection.colorKeys` for a `ui` one, and in every built-in theme under
  `Resources/themes`, which ThemeBuiltinsTests checks. The examples follow,
  being copies.
- **A new `ui` area** is a case of `InterfaceSection` with its keys, a palette
  in `Theme+ChromeColors`, and every view in it reading that palette.
- **A terminal engine.** There is one, named outright where the Mac half builds
  the model (design/terminals.md). A replacement implements the surface-host
  protocol and is passed to the model there.
- **What a host owes**: the session environment to the child, a finished command
  reported if the engine can tell, paste framed as a bracketed paste, typed text
  sent unbracketed as keystrokes so a shell runs the line, and each session's
  pty path and foreground pid where it knows them, without which Debug Info puts
  every pane under Other processes.
- **A host pastes copied files as the delegate's `textForPastedFiles` words
  them**, so an agent gets mentions, and a copied image as a file saved to the
  drops directory, only for the user's own paste (design/terminals.md).
- **A surface host also gives a pane's text, frame and last drawn image** where
  it can, which `panes read`, `tabs show` and `debug screenshot` answer from;
  one that cannot returns `nil` and the request is refused or the frame left
  out. Search counts reach the model through the delegate's `didCount`, and a
  host that sends none leaves `panes find` printing what it has at its
  two-second limit. A host that cannot say a session's terminal memory returns
  `nil`, and Debug Info leaves that screen and scrollback in the app's row.
- **A host judges a clicked link itself** before anything opens it, and hands a
  text file to the delegate's `didAskToEdit` for the user's editor. Nothing
  forces either. Left to libghostty, a link once ran whatever a program printed,
  and from `ad97d33` one from a pane's text opens nothing (design/terminals.md).
- **Two engines at once needs a multiplexer**, one host per kind and a map from
  session to kind, so a running terminal keeps the engine that opened it.
- **An agent or editor.** A row in its catalogue; detection and the dropdowns
  follow. An agent's row names its mark; its colour is a `ui.agent_marks` key in
  every built-in theme, empty where the project's mark has no colour of its own.
- **A pull request host or CI provider.** A case in `ServiceIntegration` with
  its tool's name, a conformance to `PullRequestHost` or `CIProvider` in
  MultishellServices under a folder of its own in `SCM/` or `CI/`, reading
  through `ServiceToolRunner`, and an arm in `ServiceConnections`. The
  Integrations page's label, help and install words follow, which the compiler
  asks for. A second host also needs choosing between hosts that both say a
  repository is theirs, which `pullRequestHost(for:)` does by `allCases` order.
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
  at the woken turn's Stop (design/agents.md). Four more are read only in
  Claude's format, so another agent needs a reader of its own before it can say
  yes to any: whether its transcript shows a notice still queued at a Stop or a
  question a permission prompt stands for, whether a file beside it names each
  worker's parent, and whether a tool call's result names the background work it
  launched or stopped.
- **An agent whose Stop does not list the shells it backgrounded names a shell
  marker on the integration**, text only such a shell's command line holds.
  Nothing forces it either: without one a pane waiting on the shell goes Done
  early (design/agents.md).
- **An agent reporting through a plugin** names a worker through the helper's
  subagent flags, the worker that launched it included, starts a turn through
  its new-turn flag, and at a Stop that resumes lists what is still out through
  its resumes and out flags. It also needs a catalogue row, the Agents page's
  Hooks part offering hooks for agents detection found.
- **An agent with no hooks at all needs a plugin**, as one already has. A file
  that is ours alone is written whole and deleted to remove.
- **A variable a hook receives.** A case in the hook variables, which both
  builds the environment and draws the Hooks page's table, named by the
  placeholder meaning the same, so the two cannot be spelled apart.
- **A placeholder an agent's flags may use.** A case with its value and the
  variable a custom command reads it from. The settings rows name one as an
  example rather than the list, and no page in the repository lists them yet, so
  nothing tells a user the new one exists.
- **A tab strip measurement.** The metrics bound what a tab is drawn at,
  `TabStripWidths` decides from them where the splits and arrows fit, and the
  strip layout divides the rest. `UIMetricsTests` checks across the font-size
  range that the floor leaves room for what a tab always draws.
- **The split buttons' threshold is written out in that test** rather than
  recomputed, the only place the widths are written down.
- **The buttons and both gutters come off the room first**, so nothing measures
  itself.
- **A field on a sidebar row** also goes in that row's hand-written `==`, which
  leaves the closures out; a field missing there never redraws the row, and no
  test catches it (design/appearance.md). A row of a new height goes into
  `UIMetrics.projectBlockHeight`, or the drop line lands in the wrong half. A
  field a script should read goes on `SidebarRowListing` too, filled from the
  same values the row draws.
- **A column on the Agents board.** A case in the lane enum in draw order, its
  title, the state whose colour its header wears, and a line in the lane lookup,
  total over the state so a state with no column is a compile error. The
  sidebar's counts are a separate list, `sidebarLanes`, which nothing forces.
- **Each further column asks for another column's width and gap**, and four
  already ask for more window than the app's minimum.
- **A fact on a board card.** A field on the card, filled where cards are built,
  a line in the card view and in the accessibility text, and a field on
  `BoardListing.Card` for `board list`, which nothing forces.
- **A fact off a report rather than the workspace** also needs a field on the
  session note, which carries the state it arrived with so it stops being shown
  once the pane has moved on.
- **An item on a card's context menu.** A line in the card menu: above the
  section if it acts on the pane, inside the worktree actions if it acts on the
  worktree, which puts it on the sidebar row and detail header too.
- **A strip on Debug Info.** A case in `DebugMetric` in draw order, with its
  values from a slot and its scale's floor, and its title and value text in
  `DebugMetric+Wording`. A reading no sample takes yet also needs a field on
  `DebugSample`, filled in `takeDebugSample`, and on `DebugTimelineSlot`, saying
  how a slot of several seconds combines it (design/debug-tools.md). The test
  builder `DebugSample.sample` takes it with a default, and the widest slot in
  `DebugStripLabelTests` its widest figure, so the label is held to its column.
  A series in a split strip also needs an edge in `DebugStripPoint` and in
  `DebugStripBoundary`, a band in `DebugStripChart`, a key in `debug_info`'s
  `colorKeys` and every built-in theme, read in `Theme+DebugColors` and an entry
  in `DebugSeriesLegend`, and its name in the detail line widens the label.
- **A new reading also goes in `DebugSampleRecord`** for `debug samples`, and in
  `DebugSummaryRecord` for `--summary`. Nothing forces either: left out, the
  command line never sees it.
- **A column in a debug table.** A title in the table's header and a cell in its
  row at the same `UIMetrics` width, the figure in the stacked row's caption,
  and, for Memory by tab, a part in its accessibility text and a field in
  `DebugMemoryRecord` for `debug memory`. Raise the table's width in ems in
  `DebugTableLayout` by hand. Nothing measures the columns, so one left short
  crowds them before the rows stack.
- **A keyboard shortcut.** An entry in the shortcuts table, listed in `all`,
  which both the menu item and the engine's unbind derive from.
- **A key the engine names rather than takes the character of** needs a case in
  the name mapping, or the config carries a scalar it cannot parse.
- **A combination the system owns goes in the system-owned list**, not on a menu
  item: the WindowServer takes it before a menu bar sees it. Declared but left
  out of `all` means it works everywhere but a pane.
- **The clipboard combinations are kept by the surface**; a plain key the engine
  binds that must reach the program instead is released by the engine's own key
  name, nothing of ours being on the key.
- **A dialog.** A `View` extension in a file named for it, attached by the scene
  that asks. One that removes something goes through `DestructiveAlert` and
  `destructiveAlert(_:alert:answer:)`, which keep the red button and Return on
  it; one that does not can stay a SwiftUI dialog, where the cancel role gives
  Escape and `.defaultAction` gives Return (design/smaller-decisions.md). Its
  answer is an `AppModel` method, `answerClose` the pattern, so the view only
  forwards the button chosen and the model's tests cover what it does.
- **A dialog also goes in the model's `presentations`**, topmost first, as a
  `PresentationEntry` kind whose Cancel `dismiss` calls. Nothing forces the
  list: left out, `multishell info` does not show it and `ui dismiss` cannot
  clear it, so a script stalls behind a dialog nobody sees.
- **A project icon.** A name in one of the symbol groups, or a new group. It
  must exist as far back as the deployment target; a name that does not resolve
  draws nothing rather than failing.
- **Check the system's symbol availability plist** for which release a name
  shipped in. The test resolves every name through AppKit, catching a typo but
  not a symbol too new, the test machine being newer.
- **The picker has no search**, so put a symbol in the group someone would look
  in. The same test holds every name to the width the shipped ones draw at.
- **A way of ordering worktree rows.** A case with its display name, a
  comparison in the sort rule, and a case in its tests. Raw values reach
  repositories through the shared file, so renaming one silently turns a
  committed order into the default.
- **Anything not on the worktree is passed to the sort as a closure**, as the
  active flag and the last commit are, and lands on the sort key. The sort cache
  compares keys to skip a sort, so a comparison reading anything not on the key
  serves the old order. No order lifts a row above the main worktree or the
  trunk, which the tiers place first.
- **A shell with command-status hooks.** A folder in the libraries' resources,
  copied whole in the manifest, whose init file carries the helper's and the
  agents' placeholders and joins the rest through `# include` lines, a
  `leading-path` file of its own among them. Then a path in `Paths`, a generator
  in the integration scripts, a write in the integration refresh, and a case in
  `ShellLaunch.initFileArguments`, the one way in for both a fresh tab and the
  shell taking over when an agent quits. Add its generated file to
  `everyGeneratedFileParsesInItsShell` and
  `everyPlaceholderIsFilledInAndTheAgentsAreNamed`. A shell macOS does not ship
  gets its Homebrew paths in `InstalledShells`, as fish has, so a machine
  without it drops those tests' cases.
- **It reports a command started and finished through the helper**, naming the
  program where it is one of the agents, and does nothing when the session
  variable is unset.
- **The engine's own shell integration is off** (design/terminals.md), so prompt
  marks, the directory report, the cursor's shape and the `sudo` and `ssh`
  wrappers are the new shell's scripts to write, bar what it writes itself, as
  fish 4 does its marks and directory. Without them its panes go without
  click-to-move, a clicked relative path resolves from where the pane started,
  and the shape and the wrappers are gone.
- **The refresh's new parameter takes a default**, so the test callers that pass
  it every path, `GeneratedIntegration`, `ShellTab` and ShellIntegrationTests,
  still compile without the new one and write that shell's file into the debug
  build's own integration folder.
- **As a login shell it runs agents' lines only if it is in
  `ShellInvocation.interactiveLoginShells`**; left out, they run through
  `/bin/sh` and miss its PATH. One whose syntax is not sh's also needs a branch
  picking its `leading-path` file in
  `ShellIntegrationScripts.leadingPathStatement(forShellNamed:)`, as fish has,
  or the line opens with a statement it cannot parse.
- **A shell that reads quotes unlike sh needs a branch in `ShellLine`'s scan**,
  as fish has for `\'` inside single quotes, or a placeholder in a custom agent
  or editor line runs as its variable's name (ShellLineTests). Every word the
  app types still goes through `AnyShellQuoting`, so check the new shell reads
  its spelling alike.
- **Add it to the searched shells if Homebrew leaves it out of `/etc/shells`**,
  and give it a row in COMPAT.md's table: the picker offers it, so a reader has
  to be told what it does not get.
- **A command wrapper.** A function in each shell's `command-wrappers` file,
  zsh's, bash's and fish's, run only where the user's
  `shell-integration-features` name it and standing back where they have a
  function of that name. Nothing holds the three files to one list. The bash one
  must also run under macOS's bash 3.2, which
  ShellIntegrationScriptsTests+CommandWrappers runs beside Homebrew's.
- **A second frontend.** A target in this package depending on the four
  libraries, the package exporting no library product; fix the model to its view
  type once, and implement the platform, surface host and notifier ports. The
  directory watcher and the socket are AppCore's already.
- **A port may do less.** Trash may delete outright, handing over to a running
  copy may return and leave the alert standing, a platform with no display link
  may never call back and leave the frame rate blank, and a notifier that needs
  no permission answers unavailable to both questions, which keeps the settings
  page from promising a dialog. A platform with no windows or menu bar lists
  none, and refuses `window size`, `window full-screen`, choosing a menu item
  and `debug screenshot`.
- **A command-line request.** A case in `ControlRequest`, its answer in the
  model's `reply(to:)`, which the compiler holds total, its parsing in its
  group's file under the helper's `Control/`, its arguments in the group's file
  under `Usage/` and its word in the group's line of the overview `usage`, which
  nothing checks. The model's side is tested in its AppModelControl suite
  through the fake channel.
- **A request's alerts are made in its own task**: an alert records the request
  whose task made it, and only that request answers with it and takes it down.
  Work handed to `Task.detached` or a queue callback leaves the request's task,
  so its alert stays up unanswered (design/agents.md).
- **A request over a working agent takes `--force`** and is refused with
  `agentWorking` without it. It never opens the dialog the click would. Any
  other forcing, such as a branch delete git would refuse, gets a flag of its
  own.
- **A request that runs long stops when its task is cancelled**, which the
  helper hanging up does. A stopper it holds is stopped from a
  `withTaskCancellationHandler`, as a create's is.
- **A new refusal** is a case in `ControlRefusal` and its English in the
  helper's `ControlRefusal+Wording`, naming the command that gets past it where
  there is one; the app's catalogue takes none (design/translation.md).
- **A new command group is a case of `ControlCommand`**, and the compiler then
  asks for its branch in `runControl` and its text in `usage(of:)`. Nothing
  forces its line in the overview `usage`.
- **A key `panes key` names** goes in `ControlKey.names` and in the engine's
  `namedKeyCodes`. Nothing forces the second: a name with no code stops the
  press there, the keys before it already sent, and the request is refused as
  `paneNotLive`.
- **A persisted field.** Decode with a default, an unknown enum value included,
  and add a decoding case to that type's own tests.
- **The verb carries the choice**: the strict decode where a wrong type should
  fail the file, the tolerant one where a value this build cannot read must cost
  that value alone. A lossy array drops a broken element; projects stay strict.
- **A field on `Project`** also needs its case in that type's hand-written
  coding keys, `==` and `hash`, which keep this run's read of a repo's file out
  of all three. ProjectTests lists the fields.
- **A field on `ProjectSettings`** needs a case in its hand-written coding keys,
  which keep the shell, the auto-start pair and the trust answers under their
  old keys; one left out is never saved. ProjectSettingsTests counts them.
- **A field on `Workspace`** needs a case in its hand-written coding keys too,
  which keep the shell, the auto-start pair, the worktree names, the
  notification preference and the hook timeout under their old keys.
  WorkspaceTests counts them.
- **A preference.** In order: the field on the workspace, a setter on the store,
  which must sit in that one file beside the private setter, a method on the
  model doing whatever else the change needs, and the row bound through the
  model's setting accessor.
- **A preference also needs a row in `config global`'s key table**,
  `globalSettings`, under its state-file key and through that same setter.
  Nothing forces the row: left out, the command line neither lists nor sets it.
  A project setting needs none, its keys coming from the coding keys.
- **A project override** is a second field on the project settings and a
  resolver reading those first; if a repository may ship it, a shared-settings
  field, a line in the layering and an `InheritableSettingKeys` member pairing
  the two, plus the two trust places if it names a path (design/settings.md).
- **A collection, or a reference between collections.** Extend the repair and
  the invariants. Every store operation must leave the invariants true, and the
  seeded random tests find it if not, printing the seed and step to replay.
- **Runtime state.** On the model, never the workspace. Keyed by worktree it
  also goes in the forget, or it outlives its row and the next worktree at that
  path inherits it (design/worktrees.md); keyed by project, in the project's
  removal; keyed by file tab, in `pruneFileTabs`, or a closed tab's id keeps its
  entry for the run. Nothing forces any of the three.
- **A request a view acts on is a model property the view takes** in its update,
  `takeChangeStepRequests` and `takeFileTabFocusRequest` the pattern: a SwiftUI
  bar cannot reach the AppKit view beside it, and the take, read in
  `updateNSView`, is what makes SwiftUI call the update again.
- **A value a poll or timer writes goes through `setIfChanged`**, or every view
  reading it redraws on each tick (design/merged-branch.md).
- **The session states own who clears what**: change it there and in their
  tests, not in a view.
- **A per-build file.** On the variant pattern, so a debug run never touches the
  installed app's state and two worktrees never touch each other's. A file a
  hook reads from outside either stays shared, as the hooks' helper link does,
  or has its path handed over in the environment, as the socket is for a report.
  One the helper finds for itself, as a request finds the socket, takes the
  variant of the bundle the helper sits in, its links followed, since
  `/usr/local/bin` reaches it through the build's own `cli` link
  (develop/state-on-disk.md).
- **A settings row.** Bind through the model's setting accessor, which re-reads
  the stored value; a field with its own binding goes stale against a change
  made elsewhere.
- **An override is an override section**, naming the key path once, or the
  `InheritableSettingKeys` where a repository may ship it. Help goes behind an
  (i); a caption is only for a value computed live.
- **A page that outgrows its window gets another part** in its segmented switch,
  and each part a line in ViewSettingsWindowTests. Hooks' Create part has 7 pt
  left under a repository file asking for trust.
- **A user-visible string.** A line in the catalogue of the half that says it,
  in key order under its thing's prefix (design/translation.md), and the lookup
  where the words are wanted. A word both halves say is written in both, and app
  code never reads the libraries' catalogue.
- **A form whose wording turns on a number** goes in the counted-forms file
  instead and takes the number like any other argument. Two or more arguments
  are numbered so a translation may reorder them.
- **A service a pane can reach.** A usage string in the Info.plist template, in
  this app's words, and the matching entitlement where the hardened runtime has
  one. Neither stands in for the other (design/signing.md,
  develop/permissions.md).
- **A language.** That code's folder beside the English one in both halves, both
  files translated, and a line for it in each target's resources in the
  manifest. The bundling script takes the list from the app half's folders.
- **The permission strings are not in the catalogue**: English stays in the
  Info.plist template, and a translation is an `InfoPlist.strings` in that
  language's folder in the app half, which the script copies into the bundle's
  resources on its own.
- **A notified state.** A toggle in the notification preference, whose subscript
  answers for every state so a caller can hand it whatever was reported, and a
  place in `notifiableStates`, the order the settings page lists them in. It
  also needs a case in the preference's hand-written coding keys, which keep
  Failed under `error`, and a line in its decode; one left out of the keys is
  never saved.
- **A highlighted language.** A case in `HighlightLanguage` with its extensions,
  file names and interpreters, and a row in
  `eachAddedLanguageIsPickedByItsExtensionOrName`; the grammar's row in
  `Scripts/fetch-grammars.sh`, at a tag committing its parser or a revision
  where no tag does, with its archive's SHA-256, and in `Package.swift` its
  `.package(path:)` and its product in MultishellHighlight's dependencies
  (dependencies.md); where the package drops its scanner, the scanner and what
  it includes copied under `ThirdParty/tree-sitter/`, with a README naming the
  tag and commit, and listed in `TreeSitterScanners`' `sources`; its entry in
  `HighlightGrammars.sources`; any capture name whose first component misleads
  in `HighlightCaptureRoles`, under `exceptionsByLanguage` where only this
  grammar means it so; a case in `eachGrammarColoursAWordOfItsLanguage`; and its
  notice and licence text. One that holds other languages also needs a case in
  `MarkupHost`, whose every `switch` then asks how that host reads its
  attributes, its script and style languages and its injection query.

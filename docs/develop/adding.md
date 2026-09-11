# Adding a thing

What each addition needs, beyond the code itself.

## Adding things

**A theme.** A `.json` in the themes folder (Settings > Appearance > Open
Folder), in `Theme`'s Codable shape. `examples/` is not loaded, and an example
already written is not rewritten, so keys added since appear only in a folder
seeded after them. Two keys are not colours the terminal draws: `focusRing` =
the line round the focused pane, a colour, `""` for no line, or omitted for
the theme's `selectionBackground`, which an unparsable colour also falls back
to; `inactivePaneOpacity` fades every other pane towards the theme background,
`1` fading nothing, under `0.25` clamping. Both drawn per pane by
`PaneTreeView`; see `Theme.focusRingRGB`.

**A terminal engine.** Implement `TerminalSurfaceHost`, add a case to
`TerminalEngine`, return it from `makeHost()`. Pass
`SessionEnvironment.variables` to the child. Report a finished command through
`didFinishCommandIn` if the engine can tell. Frame `paste` as a bracketed
paste where it can.

**An agent or editor.** A row in `AgentCatalogue.agents` or
`EditorCatalogue.editors`; detection and the dropdowns follow.

**A hook stage.** A case in `HookFailure.Stage`, run from WorktreeCoordinator
in order, a `PresentedError` title saying whether the operation happened, an
editor in ProjectHooksTab, a step value with its text.

**A list of files a new worktree is given.** A case in `WorktreePlacement`
with the settings field it reads, a `WorktreeOperation.Step` with its titles
and the help its Cancel shows, an editor in ProjectHooksTab, and if a
repository may ship it, a field on `SharedProjectSettings` plus a line in
`ProjectSettings.layered`. AppModel runs one stage per filled-in list, in enum
order, before the post-create hook.

**An agent's hooks.** An `AgentHookIntegration` in `AgentHooks.integrations`:
the file, the events, what each says the session is doing, and which of two
events standing for one thing is `silent` (moves the dot while the other
raises the banner). Also a row in `AgentCatalogue.agents`, since the tab
offers hooks for agents detection found. Four agents hand a command the same
payload on stdin, read by `AgentHookPayload` and mapped by `agent-hook
--agent`; one whose file is ours alone is written whole and deleted to remove.
An agent with no hooks at all needs a `.plugin`, as OpenCode has.

**A variable a hook receives.** A case in `HookVariable`, which both builds
the environment and draws the Hooks tab's table.

**A placeholder an agent's flags may use.** A case in `AgentPlaceholder` with
its value, and a line in the documentation: the settings rows name one example
rather than the list, so nothing in the app tells anyone the new one exists.
Flags are stored per agent id and split into words by `AgentFlags`.

**A tab strip measurement.** `UIMetrics.tabMinWidth` and `tabMaxWidth` bound
what a tab is drawn at; `TabStripLayout` divides the strip by them.
UIMetricsTests, in MetricsAndColourTests.swift, checks across the font-size
range that the floor leaves room for side padding, dot or icon, gap and close
button with something over for the title, and that `tabArrowWidth` holds its
own glyph with two gutters still leaving room for a tab.
`TabStripLayout.Edges` = which end has more past
it; `stepTarget` = which tab its arrow scrolls to. `newTabWidth` and both
gutters come off the room first, so nothing measures itself.

**A column on the Agents board.** A case in `AgentBoardLane`, in draw order,
with its title, the state whose colour its header wears, and a line in
`AgentBoardLane.of`, total over `SessionState` so a state with no column is a
compile error. Four columns already need ~1135pt of window against a 720
minimum; a fifth pushes that to ~1355.

**A fact on a board card.** A field on `AgentBoardCard`, filled in
`AppModel.agentBoardCards`, a line in AgentCardView and in
`AccessibilityText.card`. A fact off a report rather than the workspace also
needs a field on `SessionNote`, written by `SessionStates.report`; a note
carries the state it arrived with, and `describing(_:)` stops it being shown
once the pane has moved on.

**An item on a card's context menu.** A line in AgentCardActions: above the
`Section` if it acts on the pane, inside WorktreeActions if it acts on the
worktree (then the sidebar row and detail header show it too). Both halves
already carry a Clear Status; the section heading naming the worktree is what
tells them apart.

**A keyboard shortcut.** An `AppShortcut` in AppShortcuts, listed in `all`,
which both the menu item and the Ghostty `keybind=...=unbind` derive from. A
key Ghostty names rather than takes the character of (tab, enter, comma,
arrows) needs a case in `ghosttyName`, or the config carries a private-use
scalar Ghostty cannot parse. A combination the system owns goes in
`systemOwned`, not on a menu item: Cmd+Option+D reads as the third of the
split family but is the Dock's, taken by the WindowServer before a menu bar
sees it. Declared but left out of `all` = works everywhere but a pane.
`surfaceKeeps` = the clipboard combinations, which the terminal keeps.

**A project icon.** A name in one of `ProjectIcon.symbolGroups`, or a new
group. Must exist as far back as macOS 14, the deployment target; a name that
does not resolve draws nothing at all rather than failing. Check
`/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist`,
whose `year_to_release` maps the year beside each symbol to the macOS it
shipped in. ProjectIconSymbolTests then resolves every name through AppKit,
catching a typo but not a symbol too new for the target, the test machine
being newer. Add a line in `ProjectIcon.searchWords` where the name does not
say what it is for: an SF Symbol is named for the picture, so `cylinder` is
what a search for "database" must find. Those words are lowercase, and a test
fails on a key that no longer names a symbol. Also: no more than twice as wide
as tall, the sidebar drawing it in a square SwiftUI does not clip;
ProjectIconSymbolTests measures every one through AppKit.

**A way of ordering worktree rows.** A case in `WorktreeSortOrder` with its
display name, a comparison in `WorktreeOrder.precedes`, a case in
WorktreeOrderTests. Raw values reach repositories through `.multishell.json`,
so a new case is free but renaming one silently turns a committed order into
the default. Picker and project override follow `allCases`; their `InfoButton`
text does not. Anything not on `Worktree` is passed to `sort` as a closure, as
`isActive` and `lastCommit` are. Nothing sorts above the trunk row.

**A shell with command-status hooks.** A script under
`Sources/MultishellCore/Resources` with `__MULTISHELL_HELPER__` for the
helper's path, listed in `Package.swift`, loaded by ShellStateHooks, written
by `ShellIntegration.refresh`, picked up by ShellLaunch (and
SessionEnvironment if carried by a variable, as zsh's `ZDOTDIR` is). It calls
`multishell command-started --pid $$` and `command-finished --exit $?
--duration S`, and does nothing when `MULTISHELL_SESSION` is unset. Add it to
`ShellCatalogue.searched` if Homebrew leaves it out of `/etc/shells`.

**A platform GUI.** Depend on the four libraries, fix `AppModel<Surface>` to
the platform's view type once, implement `Platform`, `TerminalSurfaceHost`,
`DirectoryWatcher` (inotify on Linux) and `SessionNotifier`. `moveToTrash` may
delete outright until the platform has a Trash. A notifier posting without
anyone's permission answers `unavailable` to both authorization questions, and
the notification settings page then neither promises a permission dialog nor
offers to lift one; `notificationSettingsLocation` = `nil` where the desktop
has no such place.

**A persisted field.** Decode with a default, an unknown enum value included,
and add a case to DecodingDefaultsTests. `DecodingDefaults.swift` puts that
choice in the verb: `decode(_:forKey:or:)` where a key of the wrong type
should still fail the file, `decodeTolerantly` where a value this build cannot
read must cost that value alone, which is the answer for an enum a newer build
may have named. `or:` is the same fallback in both. Element-by-element decode
that drops a broken one is `LossyArray`; projects stay strict.

**A preference.** Four touch points, in this order: the field on `Workspace`,
decoded as above; a setter on `WorkspaceStore`, which has to sit beside the
`private(set) var workspace` in that one file, since Swift's `private` reaches
no further; a method on AppModel, doing whatever else the change needs (see
`setTheme`, which reapplies to the host); and the row, bound through
`model.setting(...)`. A project override is a second field on
`ProjectSettings`, a resolver on `Workspace` reading `project.settings` first,
and, if a repository may ship it, a field on `SharedProjectSettings` with a
line in `ProjectSettings.layered`.

**A collection, or a reference between collections.** Extend
`Workspace.repairReferences` and WorkspaceInvariants. Every store operation
must leave WorkspaceInvariants true; the seeded random tests find it if not,
printing the seed and step to replay.

**Runtime state.** On AppModel, never the workspace. SessionStates owns who
clears what: change it there and in SessionStatesTests, not in a view.

**A per-build file.** On the `Paths.variant` pattern, so `make run` never
touches the installed app's state and two worktrees never touch each other's.
A file that a hook or the helper reads from outside the app is the exception:
those stay shared, and the app hands the path over in the environment instead.

**A settings row.** Bind through `model.setting(...)`, which re-reads the
stored value; a field with its own `Binding` goes stale against a change made
elsewhere. An override is an `OverrideSection`, naming the key path once. Help
goes behind an `InfoButton`; a `SettingsCaption` is only for a value computed
live.

**A user-visible string.** A line in the catalogue of the half that says
it, in key order, and `t("the.key")` where the words are wanted. A word in
a view goes in
`Apps/macOS/Sources/Multishell/Resources/en.lproj/Localizable.strings`; one
in a library goes in
`Sources/MultishellCore/Resources/en.lproj/Localizable.strings`; a word
both say is written in both, and app code never reads the libraries'
catalogue.
TranslationTests, one per half, fails a key its catalogue has not got, an
entry nothing asks for, and a call that passes the wrong number of
arguments. A form whose wording turns on a number goes in
`Localizable.stringsdict` instead, with `one` and `other`, and takes the
number like any other argument; two or more arguments have to be numbered,
`%1$@ %2$@`. Views say `Text(t("the.key"))`, never a literal.

**A language.** A `<code>.lproj` beside `en.lproj` in both halves, each with
both files translated, and a `.process` line for it in each half's manifest,
`Package.swift` and `Apps/macOS/Package.swift`; `make-app.sh` puts the
code in `CFBundleLocalizations` from the folder alone, which is what makes
it pickable in System Settings. The permission strings macOS shows are not
in the catalogue: they are an `InfoPlist.strings` under
`Apps/macOS/Resources/<code>.lproj`.

**A notified state.** A toggle in `NotificationPreference`, whose subscript
answers for every state so a caller can hand it whatever was reported.

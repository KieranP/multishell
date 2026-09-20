# Adding a thing

What each addition needs beyond the code itself.

- **A theme.** A `.json` in the themes folder in `Theme`'s shape. The examples
  folder is not loaded, and an example already written is not rewritten, so a
  key added since appears only in a folder seeded after it.
- **Two theme keys are not colours the terminal draws**: the focus ring, a
  colour or empty for no line, and the inactive-pane fade, which clamps before a
  pane looks broken. Both are drawn per pane.
- **A terminal engine.** There is one and the model names its host outright
  (smaller-decisions.md). A replacement implements the surface-host protocol and
  is passed to the model in the Mac half.
- **What a host owes**: the session environment to the child, a finished command
  reported if the engine can tell, paste framed as a bracketed paste, anything
  outside its sessions dropped at shutdown, and a shared directory cleared only
  when it claimed it.
- **Two engines at once needs a multiplexer**, one host per kind and a map from
  session to kind, so a running terminal keeps the engine that opened it.
- **An agent or editor.** A row in its catalogue; detection and the dropdowns
  follow. An agent's row names its mark, and a tint where the project's mark has
  a colour of its own.
- **A new mark** needs a case in the drawn list and in the resource lookup, plus
  a single-path `.svg` of that name in the app's marks folder, in the square
  `AgentMarkResourceTests` holds them all to, with absolute commands only.
- **The monogram needs none of that** and is what an agent ships with until
  someone draws one. Give the agent a row in COMPAT.md's table, the only place a
  user reads what the app does with it.
- **A hook stage.** A case in the failure stage, an arm in each of the script
  and directory lookups, the call from the coordinator in order, an error title
  saying whether the operation happened, an editor in the Hooks tab, and an
  operation step with its text.
- **A way a worktree stage can fail.** A failure type naming what is still on
  disk, an error title, and an arm in the removal describer saying whether the
  worktree is still there, which decides whether the row is restored or
  refreshed.
- **A list of files a new worktree is given.** A case in the placement with the
  settings field it reads, an operation step with its titles and Cancel help,
  and an editor in the Hooks tab.
- **If a repository may ship that list**, it also needs a field on the shared
  settings, a line in the layering, and the four places trust and containment
  are spelled out, since it names paths on the reader's disk.
- **An agent's hooks.** An integration naming the file, the events, what each
  says the session is doing, which of two events standing for one thing is
  silent, which two are a subagent's start and end, and which is the prompt that
  starts a turn.
- **Every agent with events needs the turn-starting one.** An interrupt fires no
  hook and the workers it killed send no stop, so the next prompt is the only
  thing that empties the roster.
- **A payload names a worker by id and type**, or that agent's own spelling,
  which needs a line in the payload reader. A start or end naming no worker
  still counts as one, taking an unnamed place.
- **An agent reporting through a plugin** names a worker through the helper's
  subagent flags and starts a turn through its new-turn flag. It also needs a
  catalogue row, the tab offering hooks for agents detection found.
- **An agent with no hooks at all needs a plugin**, as one already has. A file
  that is ours alone is written whole and deleted to remove.
- **A variable a hook receives.** A case in the hook variables, which both
  builds the environment and draws the Hooks tab's table.
- **A placeholder an agent's flags may use.** A case with its value, and a line
  in the documentation: the settings rows name one as an example rather than the
  list, so nothing in the app tells anyone the new one exists.
- **A tab strip measurement.** The metrics bound what a tab is drawn at and the
  strip layout divides the strip by them. `UIMetricsTests` checks across the
  font-size range that the floor leaves room for what a tab always draws.
- **The split buttons' threshold is written out in that test** rather than
  recomputed, and is the only place the widths are written down.
- **The buttons and both gutters come off the room first**, so nothing measures
  itself. A scroll wheel is not counted in tabs at all, the strip being handed
  the turn sideways.
- **A column on the Agents board.** A case in the lane enum in draw order, its
  title, the state whose colour its header wears, and a line in the lane lookup,
  total over the state so a state with no column is a compile error.
- **Each further column asks for another column's width and gap**, and four
  already ask for more window than the app's minimum.
- **A fact on a board card.** A field on the card, filled where cards are built,
  a line in the card view and in the accessibility text.
- **A fact off a report rather than the workspace** also needs a field on the
  session note, which carries the state it arrived with so it stops being shown
  once the pane has moved on.
- **An item on a card's context menu.** A line in the card actions: above the
  section if it acts on the pane, inside the worktree actions if it acts on the
  worktree, which puts it on the sidebar row and detail header too.
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
- **A project icon.** A name in one of the symbol groups, or a new group. It
  must exist as far back as the deployment target; a name that does not resolve
  draws nothing rather than failing.
- **Check the system's symbol availability plist** for which release a name
  shipped in. The test resolves every name through AppKit, catching a typo but
  not a symbol too new, the test machine being newer.
- **The picker has no search**, so put a symbol in the group someone would look
  in. The same test holds every name to the width the shipped ones draw at.
- **A way of ordering worktree rows.** A case with its display name, a
  comparison in the order type, and a case in its tests. Raw values reach
  repositories through the shared file, so renaming one silently turns a
  committed order into the default.
- **Anything not on the worktree is passed to the sort as a closure**, as the
  active flag and the last commit are. Nothing sorts above the trunk row.
- **A shell with command-status hooks.** A script in the libraries' resources
  with the helper's placeholder, listed in the manifest, loaded by the state
  hooks, written by the integration refresh and picked up at launch.
- **It reports a command started and finished through the helper**, and does
  nothing when the session variable is unset.
- **Add it to the searched shells if Homebrew leaves it out of `/etc/shells`**,
  and give it a row in COMPAT.md's table: the picker offers it, so a reader has
  to be told what it does not get.
- **A platform GUI.** Depend on the library products, fix the model to the
  platform's view type once, and implement the platform, surface host, directory
  watcher and notifier ports.
- **A port may do less.** Trash may delete outright, handing over to a running
  copy may return and leave the alert standing, and a notifier that needs no
  permission answers unavailable to both questions, which keeps the settings
  page from promising a dialog.
- **A persisted field.** Decode with a default, an unknown enum value included,
  and add a case to the decoding-defaults tests.
- **The verb carries the choice**: the strict decode where a wrong type should
  fail the file, the tolerant one where a value this build cannot read must cost
  that value alone. A lossy array drops a broken element; projects stay strict.
- **A field on `Project`** also needs its case in that type's hand-written
  coding keys, `==` and `hash`, which keep this run's read of a repo's file out
  of all three.
- **A preference.** In order: the field on the workspace, a setter on the store,
  which must sit in that one file beside the private setter, a method on the
  model doing whatever else the change needs, and the row bound through the
  model's setting accessor.
- **A project override** is a second field on the project settings and a
  resolver reading those first; if a repository may ship it, a shared-settings
  field and a line in the layering, plus the four trust places if it names a
  path (settings.md).
- **A collection, or a reference between collections.** Extend the repair and
  the invariants. Every store operation must leave the invariants true, and the
  seeded random tests find it if not, printing the seed and step to replay.
- **Runtime state.** On the model, never the workspace. Keyed by worktree it
  also goes in the forget, or it outlives its row and the next worktree at that
  path inherits it.
- **The session states own who clears what**: change it there and in their
  tests, not in a view.
- **A per-build file.** On the variant pattern, so a debug run never touches the
  installed app's state and two worktrees never touch each other's. A file a
  hook or the helper reads from outside stays shared, its path handed over in
  the environment.
- **A settings row.** Bind through the model's setting accessor, which re-reads
  the stored value; a field with its own binding goes stale against a change
  made elsewhere.
- **An override is an override section**, naming the key path once. Help goes
  behind an (i); a caption is only for a value computed live.
- **A user-visible string.** A line in the catalogue of the half that says it,
  in key order, and the lookup where the words are wanted. A word both halves
  say is written in both, and app code never reads the libraries' catalogue.
- **A form whose wording turns on a number** goes in the counted-forms file
  instead and takes the number like any other argument. Two or more arguments
  are numbered so a translation may reorder them.
- **A service a pane can reach.** A usage string in the Info.plist template, in
  this app's words, and the matching entitlement where the hardened runtime has
  one. Neither stands in for the other (signing.md, permissions.md).
- **A language.** That code's folder beside the English one in both halves, both
  files translated, and a line for it in each manifest. The bundling script
  takes the list from the app half's folders.
- **The permission strings are not in the catalogue**: they are an
  `InfoPlist.strings` beside the app half's, which the script copies into the
  bundle's resources on its own.
- **A notified state.** A toggle in the notification preference, whose subscript
  answers for every state so a caller can hand it whatever was reported.

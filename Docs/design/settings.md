# Settings

- **Project over global; `nil` follows the global.** Blank means absent, since
  "none" and "no opinion" come to the same thing and a second sentinel would
  lose the distinction next load.
- **Four fields take blank as "none"**: worktree path, branch prefix, default
  branch, agent flags. They have no other spelling for it. Cost: a stray empty
  key there is an opinion, not a typo.
- **A repo's `.multishell.json` fills only gaps the user left.** A team default
  must never override a made choice. Of those four, agent flags are the one it
  cannot carry (agents.md).
- **What it names on disk needs trust; what it draws does not.** "Runs nothing,
  so needs no trust" was wrong: `worktreeDirectory`, `linkedPaths` and
  `copiedPaths` are paths on the reader's machine. A repo could commit
  `worktreeDirectory: ~/.claude/skills` with a `SKILL.md` and install a global
  agent skill on any create, or link `~/.ssh/id_ed25519` into a tree an agent
  reads.
- **So a repo's three are confined to the checkout**, once at read time and held
  on the project, since the sidebar asks per row per render. The tick's reader
  confines off the main actor with the parse, and export writes, stamps and
  confines there too: each touches the disk, and on a slow volume would hold the
  window.
- **The directory resolves symlinks**, so a committed link cannot carry it out.
- **Resolved as far as it exists, the rest appended**: the resolver returns a
  path that does not exist unchanged, links and all, and before the first create
  the container never exists. A link to nothing is refused, there being no
  telling where it will lead.
- **The lists are resolved lexically and must land strictly under the root**,
  the file not being there yet. `..` is resolved, never counted, so no spelling
  of it has to be anticipated.
- **Three guards come first**, or the resolve would land inside:
  `appendingPathComponent` takes `/etc/passwd` as relative, `~` is not expanded,
  and a leading `$` is refused because nothing runs a shell.
- **A refused value is dropped whole and the user's stands.** In a list the
  value is the entry, the rest of the list kept. Pointing outside is the user's
  to do in settings, not the repository's. Cost: a repo can no longer ship
  `../{project}-worktrees`, and the drop is silent.
- **Refusal reaches only what the file ships.** `place` takes
  `isRepositoryList`, false for a user's list, whose entry spelled to leave the
  root is skipped and named rather than failing the create (hooks.md), and whose
  symlinked sources may lead anywhere. Both lists take an entry as a path inside
  the repository and mirror it into the worktree; `~` and variables are never
  expanded.
- **A list is wholly one or the other.** `layered` takes the repo's only where
  the user's is blank, so a create decides it once and carries it on the value
  as `WorktreeFileList`.
- **A create re-confines against the disk** before `git worktree add`: a branch
  can commit the symlink without changing the bytes that were read, so the mtime
  never moves and the cached yes stands.
- **Confinement is not enough.** `copiedPaths: .aws.json` names something inside
  the checkout, and a gitignored `.aws.json` there is not the repo's to ask for.
  So all three wait for the one-time yes the hooks wait for.
- **The question is built from the confined value**, so the dialog never offers
  to trust a line it could not turn on, and a file whose every path is refused
  asks nothing.
- **The stored answer's key is still `sharedHooks`.** Renaming it would drop
  every answer already given.
- **Trust is per file, held against the sha256 of its bytes**, asked when a
  worktree of that project is selected and re-read when mtime moves. An answer
  is kept per version of the file: the file is tracked, so one answer per
  project would be asked again on every branch switch.
- **Layering is asked of the model**, `effectiveSettings(for:)` and
  `effectiveWorktreeSettings(for:)`, never `project.settings`. The override
  forms are the exception, where blank must keep meaning "follow the global".
- **The gate is one line.** `layered` drops what the yes covers, the same fields
  the dialog names, then puts the user's over the rest, rather than each field
  asking.
- **The forms read that same view through `inherited`**, or a caption saying
  "from .multishell.json" names a value the layering left out, as it did for an
  untrusted `worktreeDirectory`.
- **An `InheritableSettingKeys` pairs the project field with the file's once.**
  Reading the layering with the override cleared answered only for a field
  merged as `own ?? shared`; any other quietly showed the global.
- **Export writes the settings in force back over the file**, but keeps the
  file's own words where the user wrote none, or exporting would silently drop a
  teammate's committed hook.
- **Export carries the trust answer to the new digest**, records a yes where
  every word the yes covers is the user's own, and none where no answer was
  given. Comparing the two alone made trusting a file and then exporting it
  revoke the yes.
- **`carryingOver(from:)` covers every gated field, not the hooks alone.**
  Gating the directory and the lists on trust blanked them for an untrusted
  file, and export then wrote the file without those keys.
- **Grey in a hook editor means inherited, nothing else.**
- **Odd shapes, each from a bug**: no prefix on an existing branch; blank
  worktree directory is the default; `.`, `..` and an empty slug become `_`; a
  whitespace-only hook is "none".
- **Export puts the fields over the file's keys, never rebuilds the file.** A
  key this build has no field for, a `$schema` line, a newer build's order and a
  wrong-typed value all survive. Cost: the wrong type stays until someone who
  can read it changes it.
- **Integrations is per project with no global and no repository file**: it
  turns display-only reads off, and a repository without the service already
  shows nothing (services.md).
- **Help goes behind an (i).** Captions doubled every form's height and were
  read once. A caption is left only for a value computed live.
- **An (i) holds at most 200 characters once filled in**, leaving what another
  row's (i) says to it. The translation tests and AgentHooksRowTests hold the
  count.
- **A page taller than its window is split, not scrolled.** A grouped form's
  scroller is an overlay, so what is below the fold says nothing, and forcing
  the indicators changes nothing there. Project Hooks shows Create, Delete or
  Environment, six editors being 973 pt; All Projects' Agents shows Agent
  Settings or Agent hooks, the hooks growing with every agent installed. The
  parts are sidebar rows under their page, not a segmented control in the form.
- **One settings window, a sidebar of pages, for All Projects and each
  project.** Chosen over two toolbar-tab windows (2026-11-05) from mockups of
  four designs. The menu atop the sidebar picks whose settings; Project
  Settings… opens the window on that project's General, and a close returns it
  to All Projects, so Multishell > Settings never opens on a project. Cost: two
  projects can no longer be open side by side, and the window is 860 by 640, the
  mockup's size.
- **The sidebar and page sit in a plain row, not a navigation split.** Inside
  the Settings scene the split brought a sidebar button and a toolbar band of
  empty space over the page, and its search field needs the split. So the search
  is a plain field in a grey well, as the mockup drew it.
- **The title bar is hidden from AppKit**, `NSWindow.hideTitleBar`: SwiftUI's
  `hiddenTitleBar` style does nothing to a Settings scene. The sidebar runs up
  under the traffic lights and the page draws its 50 pt header over the band, as
  the workspace window does.
- **Where the window is lives on the model**, `settingsLocation`, so the
  sidebar, the command line and a Global cell's link all move it, and a scope
  change keeps the page where the other scope has it (SettingsLocationTests).
- **A project's page is a table: the setting, the Global column, the Override
  column.** The global value is read beside the override rather than in a
  caption under a greyed control, three rows becoming one. "Same" means the
  project follows; it reads "Override" under the pointer and starts one seeded
  with the value followed. The arrow hands it back.
- **That button, not a blank field, starts an override**, so the four fields
  where blank is "none" keep that meaning: an override cleared to blank is none,
  and only the arrow returns to following.
- **The Global column names its source** when it is not the global: "From
  .multishell.json" or "Detected", and only a global value links to its page.
  Default branch's "Detected" is what the scan finds with the override set
  aside, else the column would echo the override back.
- **Search matches every word typed against a page's title and row labels**,
  listed beside the page (`SettingsPage+SearchTerms`). Cost: a row added to a
  page and not to that list cannot be found.
- **The pages are drawn to the mockup, not a grouped `Form`.** The Form gave a
  white page under grey cards, 13 pt bold group titles and grey fields, the
  mockup's inverse. `SettingsForm` and `SettingsGroup` lay out its metrics, kept
  in `UIMetrics`, in `SettingsColors`' light and dark values; a row is a
  `LabeledContent` or `Toggle` in its own style, and a `SettingsCaption` sits
  under the row before it unruled. Menus are `SettingsPopUp`, buttons
  `SettingsButtonStyle`. Cost: a native control the pages use must be given the
  mockup's face by hand.
- **The sidebar is drawn too**, its rows buttons and the arrow keys a model step
  (`stepSettingsSection`), the page glyphs the mockup's own strokes. The sidebar
  `List`'s material rendered its text in vibrancy and drew a rule under the
  title bar in an inactive window.
- **The window hides its title bar from AppKit and its toolbar's background**
  (`toolbarBackgroundVisibility`): with the background, macOS faded the page
  header's text under the band; hiding the whole toolbar took the traffic lights
  with it.
- **Reviewed and left as is**:
  - Section and command-line page words convert by two switches, not raw values:
    each is exhaustive, so a new case fails the build until both name it, where
    a raw value would fail only at run time.
  - The Global column builds the shell or agent menu's options to word the value
    as the menu does: a catalogue's dozen entries, as the menu beside it builds
    anyway.
  - Unproven: whether Up and Down reach the sidebar while the search field has
    the keyboard. The sidebar takes focus once tabbed to.
  - Unproven: that moving from one project's Integrations to another's runs the
    old page's stop after the new page's start, leaving tool status unasked
    until the page reopens. It turns on SwiftUI's appear order.
  - Unproven: that a switch row's hidden inner label, the visible label
    repeated, adds a second (i) VoiceOver reads.
  - The Window menu no longer lists Project Settings, the scene that put it
    there being gone; the sidebar's menu and the scope menu reach a project.
  - `ui show settings` turns an open window to All Projects while Cmd+, brings
    it forward as it is: the command line's word names the scope.
  - Search does not find an agent's name: its hook rows exist only for agents
    installed, and the terms are fixed per page.
  - The scope menu repeats `SettingsPopUp`'s Menu and Picker around its own card
    face; a label parameter on the pop-up would serve this one caller.
  - Hooks has no whole-page `--page` word, its three parts each having one.
  - `SettingsColors` converts its hex constants itself: `RGB`'s initialiser is
    Core's own, and widening it for six constants costs more than eight lines.
  - The detected default branch is a dictionary beside `defaultBranchScans`, not
    a field on it: that enum is built in tests across four suites.
  - A raw socket request naming a project with `inProject` false opens All
    Projects; the bundled command line never builds that shape.
  - Unproven: that a ref read failing on every tick, while the worktree list
    reads, leaves Default branch saying Detecting… for good.
  - An unknown `--page` word is answered with every word: the helper does not
    know which pages each scope has, and the app's refusal names them exactly.
  - `SettingsForm` still sets the button style for its page: every plain button
    on a page wants it, and the three that draw their own opt out.
  - Unproven: that a page's column is 590 pt, the content running up under the
    title band, rather than the 558 pt `settingsPageSize` holds pages to. The
    tighter bound costs only an earlier split.
  - The auto-start switches disable whole, (i) included, with no agent chosen,
    as they did before the merge; only the Flags field is new.
  - Unproven: that a double-click on the header minimises the Settings window,
    which has no minimise button, when the system setting says Minimize.
  - `ProjectHooksPage` takes a `SettingsSection` and draws nothing for one not
    Hooks': `SettingsDetail` is its one caller, and a type of its own for the
    three parts would be one more switch to keep.
  - The Global column's own `globalValue(_:setIn:)` stays beside
    `InheritedSetting`'s: building an `InheritedSetting` to word a menu label
    reads as a value inherited, which it is not.
  - The Flags row reads the global line twice, once for the column and once to
    seed an override: two dictionary reads a render.
  - `AuxiliaryWindow` keeps its one case, so the port names the window it opens.
  - The search terms per scope are fixed lists in AppUI, where the words are.
  - A branch scan with an override resolves the refs twice, once more for the
    Detected cell: an in-memory pass over the refs already read.
  - `PathText` writes home as `~` everywhere, the New Worktree sheet included,
    whose planned location already did.
  - The window's button, switch and pop-up styles stay in `Settings/Layout/`
    beside `SettingsToggleStyle`: splitting styles by which control wears them
    would part four of five.
  - (i) buttons and the Global cell keep the system's `.secondary`; titles,
    headings and captions take `SettingsColors.secondaryText`, so the override
    table's heading matches a group's title.
  - `ThemePicker` stays in `Shared/` although only the Terminal menu draws it: a
    folder follows what a file is, not how many places call it.
  - `Theme.builtins` and `theme(from:)`'s default stay public: 24 AppUI test
    files name them without `@testable` importing Core.
- **A hook file opens in a popover**, which inline added 166 pt a row.
- **Which states raise a banner is three toggles, not one picker.** The picker
  offered three of the eight answers and could not say "only when something
  failed", which is all some people want.
- **Cost of that**: a state file written by this build reads as off on a build
  with the picker. One caption at the foot says what holds for every toggle,
  where three (i) buttons said it three times.
- **Permission is asked as the toggle goes on**, not at the first report, so the
  dialog arrives while the user is looking at the thing it is about and a
  refusal can be answered where it is read.
- **The answer is runtime state**, re-read as the page opens and as the app
  returns to the front, the way back from the settings the caption points at.
- **Export stores its trust answer before the write**, the digest being known
  from the bytes. Stored after, a poll reading the file in between asked the
  user to trust hooks they had just exported, and nothing withdrew it.
- **Exports land in the order they were asked**, through the `SaveOrder` ticket
  the store's saves use, one order per project. Two on a slow volume otherwise
  landed backwards, the older overwriting the newer, and a late finish recorded
  the older's bytes, even with the newer still being written.
- **An editor's tab turns to its worktree through `select`, as a click does.**
  It selected through the store and skipped the question, so a tab opened in
  another project's worktree ran with that file unasked about
  (AppModelSharedSettingsTests).
- **`config project set` decodes the new settings back before it saves them**,
  and refuses a value the decoder would drop or change: a blank agent id, a tint
  off the palette, `null` on a hook, which has no global to follow. Saved as
  given, it would read as unset on the next load. The trust answers are not
  settable there at all (agents.md; AppModelControlProjectSettingsTests).

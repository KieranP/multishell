# Shortcuts

Changing a menu command's keys in Settings > Shortcuts, and what holds the menu
bar, the terminal surface and the text that quotes keys to one answer. Newest at
the bottom.

- **The page is the project pages' override table turned to shortcuts**, Default
  and Yours, picked from mockups on 2026-11-18 for matching the other settings
  pages. Not picked: one column of keys per row with no Default column, and a
  page listing only the changes with an Add Shortcut… picker.
- **Global only.** A project has no Shortcuts page; keys are the app's, not a
  repository's.
- **Four parts, File, Edit, View and Terminal, each card a run of a menu's items
  between two dividers**, so the cards read as the menus do. 34 rows at 36 pt do
  not fit the 608 pt window, and a page is split rather than scrolled
  (settings.md).
- **One table of defaults, `ShortcutCommand` in Core.** The menus, the engine's
  unbinds, the settings rows and the command line all read it, so a default
  changed there reaches all four.
- **Only changes are stored**, keyed by the command's raw value, which never
  changes, so a default a later build changes still reaches a command the user
  left alone. Blank is "no keys", the menu item staying, as the four
  blank-is-none fields read it.
- **Hand-written `Codable`.** A synthesised enum-keyed dictionary encodes as an
  array, a nil as `null`, and assigning nil to a dictionary deletes the entry
  rather than storing "no keys".
- **Punctuation is spelled by name in the file**, `cmd+backslash`, so `+` never
  parts a combination and a quote needs no escape.
- **The decode drops a bad entry alone**, a second claim on keys included, the
  earlier command in `ShortcutCommand` order keeping them.
- **Where a later build's new default lands on an override, the override wins**
  and the command with the new default has no keys. The user chose the override;
  the default was nobody's choice.
- **Undo, Redo, Find, Cut, Copy, Paste and Select All are fixed**, the owner's
  call on 2026-11-19: every Mac app gives them these keys. Their keys count as
  held, so no command can take them.
- **Fixed is not kept by the pane.** Only the clipboard four stay bound in a
  pane (`surfaceKeepsBinding`), being Ghostty's own copy and paste
  (terminals/engine-and-config.md); ⌘Z, ⇧⌘Z and ⌘F are still unbound, or
  Ghostty's own search bar takes ⌘F.
- **Refused, the row saying why and still recording**:
  - a key with no ⌘, ⌃ or ⌥, F-keys excepted: every text field would lose it;
  - ⌥ with a character key and neither ⌘ nor ⌃: it types a character on many
    layouts (⌥L is @ on a German one) in every text field;
  - the reserved table, `ReservedShortcut`: the quit, hide, minimise, settings,
    full screen and window or app switching keys every Mac app shares, ⌥⌘D (the
    Dock's hiding, which the WindowServer takes before a menu bar sees it), ⌘↩,
    which is also the review composer's Send, the Apple menu's, and the system's
    own hotkeys, which no menu sees: screenshots, Spaces and Mission Control,
    Finder search, VoiceOver and the Accessibility Shortcuts panel, Look Up, and
    input sources. The page cannot record those, but the command line and a hand
    edit could set them;
  - ⌃C, ⌃D, ⌃Z, ⌃\\ and ⌃[, which a pane's program needs, ⌃[ being Escape;
  - ⌃↩ with any other modifier, and ⌃/ alone, which the pane types before any
    menu sees them (`GhosttyKeyEquivalent.offer`), so a menu item on them would
    never fire over a terminal;
  - ⌥ with Delete, Forward Delete, an arrow, Page Up or Down, Return or Tab and
    neither ⌘ nor ⌃: they move, delete or break a line in every text field, as ⌥
    with a character types one. ⌥Home and ⌥End do nothing there, so they are
    allowed with the pane warning;
  - ⌘., AppKit's Cancel for a sheet, an alert or a field's edit;
  - ⌘ or ⇧⌘ with an arrow or Delete, and ⌃⇧ with a sideways arrow, which every
    text field uses to move, select or delete to a line's or the text's ends;
  - AppKit's own items, ⇧⌘\\ for Show All Tabs, ⇧⌘/ for Help's search and
    ⌃⌘Space for Emoji & Symbols, which nothing of ours declares. Unproven here:
    AppKit adds them as a menu opens, so `multishell ui menu` never lists them.
- **Allowed with a warning: keys without ⌘ are taken from every pane.** The row
  says so for as long as the change stands, and names what the shell's emacs
  line editor loses where it is known, "⌃R, the shell's history search".
- **Keys another command holds ask first**: Replace leaves that command with no
  keys, Cancel keeps both as they were. The reset arrow asks the same where the
  default now belongs to another command, so no path leaves two commands on one
  key.
- **One judge, `ShortcutOverrides.judge`**, for the page, the reset arrow and
  `config global`, so none lets through what another refuses.
- **Restore Defaults sits in the page header and asks once, inline**, before
  clearing every change in every part. Not per part: a part is a fit to the
  window, not a unit anyone restores.
- **The engine is told to unbind every command's default and override but the
  clipboard four's.** Unbinding a freed default too keeps a freed ⌘F from
  reaching Ghostty's own search bar, which an embedding never shows. The whole
  reserved table is unbound as well, replacing the old system-owned list, so the
  judge and the unbinds cannot disagree.
- **Re-applied on every change, as a theme is**, so open panes take new keys
  without a restart.
- **A character key is unbound twice, by character and by Ghostty's name for the
  key** (`bracket_left`, `digit_1`, `key_k`). A character binds the key typed
  and a name the physical key, and an unbind removes only the trigger spelled
  the same way. Ghostty's defaults use both: `super+[` by character, ⌘1 to ⌘8
  under both. The issue planned names for punctuation alone.
- **`>` has no trigger**: Ghostty reads it as the step between a sequence's
  keys. Nothing in its defaults is on it.
- **Every recordable key runs through libghostty's own parser in a test**
  (`KeyCombinationGhosttyTests`), libghostty dropping a line it refuses without
  a word.
- **The menu items are set twice**: SwiftUI's `.keyboardShortcut` reads the
  model, and `MacPlatform.setMenuShortcuts` sets each item's key equivalent by
  title after every change, SwiftUI not reliably redrawing `Commands`. The quick
  switcher and `multishell ui menu` read the `NSMenuItem`, so they follow.
- **A changed command's keys skip SwiftUI's layout localisation** (`.custom`,
  and `allowsAutomaticKeyEquivalentLocalization` off): they were typed on this
  layout, and remapping would move them to where the US key sits.
- **The recorder is an `NSEvent` local monitor**, which sees a key before the
  menus do and swallows it, so typing ⌘W records ⌘W rather than closing the
  window.
- **A named key's glyph spelled as the key is that key**: `cmd+←` from the
  command line is the arrow, not a character no key types. A glyph for a key
  with no case here, ⏎ or ⎋, is refused rather than kept as a character.
- **The key is the layout's character with no modifier pressed**,
  `characters(byApplyingModifiers: [])`, as a menu's key equivalent matches.
  Except an F-key or arrow, where that translation gives a control code (0x10,
  0x1C), not the private-use character AppKit's menus use; those come from
  `charactersIgnoringModifiers` (`ShortcutRecorderInputTests`).
- **In `config global`, a command left to a default another's change took reads
  blank, not `none`**, which would write a change back.
- **The three questions the issue left open went as mocked**, pending the owner:
  keys without ⌘ are allowed with the warning rather than refused, a bare F-key
  is allowed, and Restore Defaults is once for the page.
- **A command whose default another's change holds says so under its row**, or
  it read "Same" while having no keys.
- **An open question, a row's or Restore Defaults', ends when the overrides
  change**, as Restore Defaults or the command line can change them under it,
  and when the page goes. Keypad Enter is not recorded: its key equivalent is
  not Return's, so the menu would not fire on it.
- **The recorder takes keys typed in its own window only**; a key in another
  window ends recording and goes through, or a Delete in a pane cleared the
  command.
- **Focus Next and Previous Pane are ⌘] and ⌘[**, Ghostty's own `goto_split`
  keys and iTerm's, so they take the keys a pane already had for this. They walk
  the tab's panes in reading order and wrap, as the group pair does; a direction
  per arrow would take ⌘⌥← and ⌘⌥→ from the groups.
- **Filter Projects is ⌥⌘P**, P for projects beside the switcher's ⌘P; ⌥⌘F is
  Close Find. It opens the sidebar's field or, already open, takes the keyboard
  back to it, keeping the text. The Files panel has no such command: the quick
  switcher reaches its files.
- **The menus' groups are the owner's, set on 2026-11-20**: File is New Project
  and New Worktree, the three new tabs, Open in Editor, then the closes; View is
  Agents Dashboard, the Files panel, the quick switcher and Filter Projects,
  then Theme, moved from Terminal; Terminal is the splits, pane focus, tabs,
  then Move Tab to New Group with group focus. Add Project became New Project,
  its state file key staying `add-project`. The board is the Agents Dashboard.
- **Only a part's first card has a heading row**, Default and Yours over the
  columns the cards below share, as their widths are fixed. Four Terminal cards
  each with a heading needed 563 pt of a 558 pt column. The row has no title,
  the sidebar naming the part, and so no (i) on Edit's keys; the owner's call on
  2026-11-20.
- **Reviewed and left as is**:
  - Filter Projects stays ⌥⌘P, the owner's call on 2026-11-20, though ⌥⌘F is the
    Mac's "go to the search field" and ⌥⌘J Xcode's Filter in Navigator. ⌥⌘F
    would mean moving Close Find off it.
  - ` (⌘T)` is formatted in both halves, `keysInParentheses` in AppUI and
    `TabStripButtonText.splitHelp` in AppCore, each from its own catalogue: a
    view never reads the libraries' words (translation.md).
  - Searching a command's title opens Shortcuts' first part, File, not the part
    listing it, as a split Agents or Hooks page opens its first part.
  - Keys are judged as spelled: `cmd+?` from the command line or a hand edit is
    the character ?, which a US layout types as ⇧/, so it passes where ⇧⌘/ is
    refused. Mapping it needs the keyboard layout, which Core cannot read, and
    on a German layout # is a key of its own. The recorder writes the unshifted
    key with Shift, so the page never makes one.
  - Ghostty's names for punctuation repeat the state file's words in a table of
    their own: the file's words are fixed with the file, Ghostty's follow its
    pinned build, and one table would let an engine rename change the file.
  - Shortcuts has no whole-page `--page` word, its four parts each having one,
    as Hooks has none (settings.md).
  - A ⌘ combination that is Ghostty's own pane action, ⌘K's clear or ⌘='s zoom,
    is unbound without a warning: AppCore names no engine, so it cannot know
    which keys one binds.
  - ⌃ and a letter is allowed with the pane warning, though text fields lose
    their emacs key too: the issue allows it, naming "⌃R … history search".
  - Unproven: that holding keys just recorded, ⌘W say, lets the key's repeat
    reach the menu once the recorder has gone. Holding a key cannot be driven
    here, and the fix, committing on the key's release, would go untested.
  - Unproven: that a recorder can start with no window key, which would end it
    at the first key. A click on Same makes its window key before it acts.
  - Unproven: F11 for Show Desktop and ⌃F1 to ⌃F8 for keyboard navigation, which
    some Macs turn on, are not reserved; whether they are on by default varies
    by machine.
  - A bare F-key stays allowed though F5 is completion in a text field: few use
    it, and F-keys are the one no-modifier key the issue keeps.
  - Unproven: that on AZERTY, whose number row types & é and so on, ⌘& is
    unbound as a character but not as the physical `digit_1` Ghostty binds, so a
    pane would take it. The fix stores the key code with the keys, and the
    layout cannot be switched to show it.
  - Unproven: that on a non-Latin layout, Russian say, ⌘ and the K key records
    as ⌘к, which a menu matching the layout's command layer, ⌘K, would never
    fire. Switching the layout in a test would change the account's input
    sources.
  - Unproven: that SwiftUI never rebuilds a menu item from a stale `Commands`
    body after the AppKit pass. It reads the same model, so a rebuild carries
    the same keys.
  - Unproven: why the system owns ⇧⌘N. It was on the system-owned list since the
    first commit; the refusal says only that macOS keeps it.
  - `MenuShortcutText` still draws a menu item's keys from AppKit's own
    characters rather than through `KeyCombination.glyphs`: it reads any item,
    the system's included, with F-keys to F35 and fn.

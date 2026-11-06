# Interface

What each addition to the interface needs beyond the code itself: themes, views,
shortcuts, dialogs, icons and row orders.

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
  test catches it (design/appearance/window-chrome.md). A row of a new height
  goes into `UIMetrics.projectBlockHeight`, or the drop line lands in the wrong
  half. A field a script should read goes on `SidebarRowListing` too, filled
  from the same values the row draws.
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

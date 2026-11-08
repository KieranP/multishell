# Themes and colours

Theme files, what each key colours, the built-in themes and how a saved theme is
reloaded. Newest at the bottom.

- **Themes are hex strings**, six digits or eight with an alpha (three or four
  as shorthand), so the core imports no UI framework and user theme files come
  free. Cost: the window follows the theme's `is_dark`, not the OS mode.
- **The theme sets the engine's search colours**, or it paints matches in its
  own defaults. The base themes paint matches in their yellow, the selected one
  in the ring's colour, both with whichever of background and foreground is
  darker as their text, since white on yellow cannot be read.
- **That layer sits over the user's Ghostty config**, so a search colour in
  their file is read and then overridden, as their background is. The family
  stays allowed because it carries nothing else a surface reads.
- **The debug tools split the app from its children in blue and yellow**, the
  base themes' `debug_info` series, a pair every kind of colour blindness still
  tells apart. Cost: a theme setting them close loses the split. The terminals'
  memory is the same blue paler, being inside the app's process, and the legend
  names it, so no colour carries it alone.
- **A theme file has `terminal`, `file` and `ui` sections**, so one part of the
  window is recoloured without touching the rest. Keys are snake_case; `ansi`
  and `ui.project_icons` are maps by colour name, `ui.agent_marks` by agent id.
  A file in the flat shape before sections is refused with a message saying so,
  rather than drawn as the base under its own name: no migration, by choice.
- **Every key falls back on a base theme**, Multishell Dark or Light by the
  file's `is_dark`, dark where it is left out, never on the theme's own
  terminal. A key left out, of the wrong type or that will not parse takes the
  base's, so a typo costs that colour and a theme need write only what it
  changes. Cost: a theme recolouring its terminal alone keeps Multishell's
  chrome around it.
- **The built-in themes are complete JSON files in Core's resources**, read at
  launch, and an example is a byte copy of one: what a user copies is what the
  app draws, every key in it. ThemeBuiltinsTests holds each to every key.
- **An example that differs from its built-in theme is rewritten** when the
  folder is opened, an old one hiding keys. Cost: an edit made to an example is
  lost; the copy to make is beside it. An `example.<id>.json` an earlier build
  wrote is deleted at load, being a flat file no build reads.
- **A key a section does not list is never read**, so a theme cannot set a
  colour nothing draws, and the examples list only what does something.
- **Fainter text, lines and fills are keys of their own**, written with their
  alpha, where they were once one text colour at fixed opacities.
- **Some areas take another's colours where they are drawn on it**: a shown tab
  reads in `terminal_tab` or `file_tab`, whose background it joins, and the find
  bar's text sits on its `field_background`. A `tab_bar` text picked for a light
  strip vanished on a dark tab.
- **Idle's grey is the `text_tertiary` of the area it sits in**, so a light
  sidebar under a dark terminal keeps its idle dots.
- **libghostty takes no alpha**, so a terminal colour's is dropped on the way to
  it; the focus ring, drawn by the app, keeps its own. `cursor_text` and
  `selection_foreground` left empty are not sent, leaving the user's own Ghostty
  config or libghostty's default, which keeps each cell's colour.
- **The settings window and dialogs stay out of the theme**, following the
  system appearance as their forms do. So do menus once open, tooltips and the
  spinners, which AppKit draws.
- **Controls AppKit would draw in its own grey are drawn by the app** inside the
  themed areas: the actions menus' buttons, through `glyphMenuStyle`; the
  Modified/Branch, Unified/Split and Debug Info range switches, as
  `SegmentedSwitch` on their section's `fill` and `selection_background`; Pause,
  as one segment; the board's toggle, on the header's `accent` or `fill` and its
  `knob`; and every field's prompt, laid over the field in the area's faintest
  text.
- **MonochromeThemeTests renders the window with every colour white, then
  black**, and fails on any other pixel, which is the test for a part the theme
  does not reach. It allows two steps a channel: a menu button's glyph is
  colour-matched once more and lands at 254.
- **A theme saved in the themes folder is drawn at once**, the folder riding the
  one FSEvents stream the worktrees use and made before it is armed, as the
  watcher skips a folder not there yet. The engine keeps its own copy of the
  colours, so a reload that changes the theme in force sends it again; the
  Reload button once left the terminals in the old one.
- **The folder is read off the main actor, and a read overtaken by a later one
  is dropped**, as a stale re-arm is, or a slow read would put an older theme
  back until the next save.
- **A broken theme file is alerted once, by name**, every file newly broken in
  one read named in one alert: a save elsewhere in the folder, fixing one of
  two, or saving a broken file again still broken raises nothing. Files are
  known by name, the decoder's text varying between reads of one file.
- **Colours are parsed from the theme's strings on every read, not cached**, and
  a palette resolves only the colour a view asks for. The parser reads the bytes
  in place, 1.0 µs a colour in a debug build where allocating cost 2.6 µs. A
  cache inside the theme would need an init order the base themes, each its own
  fallback, cannot give.
- **Ten editor themes ship beside the base ones**: Dracula, One Dark, Nord,
  Solarized Light, GitHub Dark and Light Default, and Catppuccin's Mocha,
  Macchiato, Frappé and Latte. Each is a complete file, so none borrows
  Multishell's chrome, and each takes its colours from its own source: the
  published VS Code theme for Dracula, Nord and GitHub, Atom's Less variables
  evaluated for One Dark, VS Code's built-in port for Solarized Light, and the
  palette file and style guide for Catppuccin. A role a source leaves unset
  comes from that theme's own palette. None takes Claude Code's diff colours.
- **Search text must read at 3:1 on its match**, which GhosttyAppLayerTests
  checks for every built-in. It overrides a source that fails it: Catppuccin's
  guide puts Text on Teal, about 1:1 in the dark flavours, so its own rule for
  text on an accent, Base, is used instead.
- **The faint tier clears 3:1 on the sidebar**: the base themes' `text_tertiary`
  went from 0x61 to 0x66 dark and 0x81 light, every `ui` area alike, from 2.97:1
  and 2.23:1 to 3.13:1 and 3.09:1 on the sidebar. A selected row's wash takes it
  to 2.68:1 and 2.89:1, and the file tab's line numbers and comments, `file`
  keys, keep 0x61. It carries the idle ring, branch prefixes, unselected pages,
  the header path and position badges. Cost: Light's secondary and faint tiers
  sit closer, 0x99 against 0x81. Picked over raising the side panels alone, two
  faint tiers in one window, and over a key of idle's own, which would reverse
  idle's grey above.
- **The editor themes' `tab_bar.fill` is their own text, translucent**, a key
  their sources have no counterpart for: 8%, or 16% where the terminal is
  lighter than the strip and 8% came out its colour, 12% in Solarized Light.
  Their header fills, opaque in eight, hid a tab's lit X on its hover wash and,
  where the fill matched the border, the shown tab's side. Every built-in's wash
  stands 1.1:1 off its strip and its shown tab, and the X's square 1.1:1 off the
  wash (Theme+TabStripColorsTests).
- **Every area a glyph lights in holds its `fill` 1.1:1 off its ground**
  (GlyphHoverModifierTests), departing from three sources: GitHub Dark's sidebar
  fill at 13% where it was 10%, and GitHub Light's sidebar and find bar and
  Solarized Light's sidebar, header and find bar in their own text, translucent,
  their source fills being too near the ground at any alpha. The same key paints
  the count capsule, the filter wells and the switches there.
- **A text field's selection and caret are its area's `selection_background` and
  text**, set on the window's field editor while the field has the keyboard.
  AppKit takes both from the system accent, and SwiftUI's `tint` lightens the
  selection towards white. `find_bar`, `tab_bar` and `terminal_tab` took a
  `selection_background` for it, each built-in's `quick_switcher` one, as
  `file_tab`'s is white in Multishell Light.
- **A selection in a view without the keyboard stays AppKit's grey**, a file
  tab's while its find bar has the keyboard, or a field's in a window not key.
  No public API sets it; overriding the private `_selectionBackgroundColor`
  worked and was declined (2026-11-07).
- **A theme sets how big the state dots draw**, `ui.state_dot_scale`, one
  multiplier over every dot's design size, so they keep their proportions to
  each other. Built in at 1.3 (2026-11-08): at their design sizes the dots read
  too small. A file tab's change dot scales with them, matching the state badges
  beside it in the strip, and a scaled corner badge keeps its centre, growing
  evenly rather than all inward over the mark.
- **The dot scale is clamped to 1 to 1.4.** Under 1 the rings' minimum strokes
  fill a dot and working reads as done; past 1.4 a worktree's dot outgrows the
  sidebar's glyph column at the 10 pt UI font. UIMetricsTests holds the upper
  bound to that column.

## Reviewed and left as is

- **GlyphHoverModifierTests lists the five areas lit today** (round 14): a
  caller in a new area adds it, as it adds the area's `fill` to its section.
- **The theme-contrast suites are named for the view whose colours they hold**
  (round 16): GlyphHoverModifierTests, PlaceholderButtonTests and
  Theme+TabStripColorsTests, as View+RowSelectionTests is, the view being where
  a reader looks for what its colours must clear.
- **The missing-project badge keeps its design size under the dot scale** (round
  1 of the dot scale review, 2026-11-08): it is a question mark saying the
  folder is gone, not a state or a change, and nothing beside it scales.
- **A corner badge's caller passes the scale its badge draws at** (round 2 of
  the dot scale review): `StateDot` reads the theme's itself, so the modifier is
  told rather than reading the badge. A badge that does not scale passes 1 and
  still sits right.

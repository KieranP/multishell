# Appearance and window chrome

- **Themes are hex strings**, six digits or eight with an alpha (three or four
  as shorthand), so the core imports no UI framework and user theme files come
  free. Cost: the window follows the theme's `is_dark`, not the OS mode.
- **The window chrome is drawn by hand.** Recent macOS renders split-view
  sidebars as floating glass, and the AppKit split sizes children however it
  likes and exposes nothing.
- **Cost of that**: sidebar keyboard navigation has to be built, and each
  hand-drawn row needs an accessibility label reading its glyphs in order.
- **Every header along the top stands in for the title bar at the metric's
  height**, the band a hidden title bar keeps. Anything shorter, or anything but
  a header reaching into that band, and AppKit paints over it.
- **Nothing collapses the sidebar**, the traffic lights needing something under
  them.
- **Row heights are asked of one place**, by the row that draws it and by the
  sidebar counting a project's block. The two disagreeing puts the drop
  indicator in the wrong half.
- **One workspace window, never a `WindowGroup`.** Each surface is one `NSView`,
  and a second window would steal it.
- **Project settings is a `Window` too**, because a `WindowGroup` adds its own
  Close and AppKit gives Cmd+W to the first matching item, so that Close beat
  Close Pane and shut the app.
- **A settings window opens centred on the workspace's screen**, first tab,
  scrolled to the top. SwiftUI reshows the same window, so the close places it
  while nothing is on screen to jump.
- **The focus ring and the fade are theme keys.** A hairline in the selection
  colour was the wrong answer at a glance once groups made the question sharper.
- **The ring may be any colour, or empty for no line**; the fade dims every
  other pane towards the terminal's background. The built-ins ring in a colour
  of their own, never the selection colour, which is mixed to sit under text and
  reads as a smudge.
- **An unparsable ring falls back to the base theme's** rather than reading as
  off: a typo should cost the colour, not remove what the key sets. The fade
  clamps before a pane looks broken rather than unfocused.
- **The fade is a scrim in the terminal's background, not view opacity.** A
  pane's surface is Metal-backed. Hit testing is off, so a click still reaches
  the terminal and undims it.
- **Cost of the scrim**: a light theme fades towards white, a wash rather than a
  dimming, and a theme turning both off has nothing left to say where the
  keyboard is.
- **The find bar floats, drawn as Ghostty draws its own**: a rounded panel
  lifted from the terminal under a hairline, the field in a well one step back,
  glyphs that light on hover.
- **Multishell Light lifts its find bar less**, towards black, or the sidebar's
  own lift reads as a grey slab over a white terminal. Its well carries a
  `field_border`, being too near white to tell apart.
- **No shadow**: SwiftUI shadows every opaque part of a view, so one meant to
  lift the panel also blurred around the well inside it. The lift is the
  hairline's to give.
- **Not a strip across the pane.** A strip takes a row from every pane it is up
  in; a bar floating over the corner costs the terminal nothing.
- **The match count sits at the end of the well, as Chrome's "1/34"**, grey and
  in fixed-width digits so it does not jitter as it counts. Nothing shows until
  the engine has counted, `-/34` before a step selects a match, and `0/0` for
  none (`FindMatchCountTests`). VoiceOver hears "match 1 of 34".
- **The theme sets the engine's search colours**, or it paints matches in its
  own defaults. The base themes paint matches in their yellow, the selected one
  in the ring's colour, both with whichever of background and foreground is
  darker as their text, since white on yellow cannot be read.
- **That layer sits over the user's Ghostty config**, so a search colour in
  their file is read and then overridden, as their background is. The family
  stays allowed because it carries nothing else a surface reads.
- **A board card has two fixed lines, read top down as the sidebar is**: mark,
  project, branch and git badge, then the tab title and elapsed time.
- **The agent's name came off the card.** The tab title almost always repeated
  it, and the mark says what is at the prompt however the tab is named.
- **The tab title is one line, truncated, and the badge shares the branch
  line.** What a card said about itself used to move under a title that took a
  second line, and the eye could not find it twice in the same place.
- **The message block below stays one to three lines and optional**, so cards
  are not all one height. It is the occupant's words and the one thing on the
  card worth the room. Cost: a long command is cut off.
- **Project settings hosts an AppKit tab controller** in the toolbar style
  SwiftUI gives only to the settings scene, and asks about removing a project in
  that window, or the dialog would be behind it.
- **The terminal font is picked, not typed**, some programming fonts not being
  marked fixed-pitch.
- **The UI font's family is a setting of its own beside its size**, so the
  chrome can match the terminal or editor font someone reads all day. Code,
  paths and commands keep the system monospace, and the settings windows and
  dialogs keep the system font, their forms being AppKit's grouped style.
- **A project icon is tinted from a slot of the theme's `ui.project_icons`, not
  a hex**, so a theme change recolours it. The slots are named as the ANSI ones,
  being saved as their number, but no longer follow the terminal's.
- **The icon comes from a grouped palette read by shape**, not a menu of names
  read line by line: the menu held the list to a few dozen where the palette
  carries hundreds. Still keyboard-drivable.
- **Emoji are gone**, having looked out of place. A glyph is a symbol name or
  nothing, one rule read the same way everywhere, so a leftover neither masks
  the icon a repo's file names nor is written back into it. Cost: a project that
  had one draws the folder.
- **Sidebar rows compare everything but their closures**, so SwiftUI skips a row
  whose state has not moved. The closures are rebuilt on every render and never
  compare equal. Without the comparison each rebuild re-ran every row's tooltips
  and accessibility label, about half a millisecond at 40 rows.
- **Cost of that**: a field added to a row and left out of its `==` never
  redraws the row, and a closure that comes to capture more than the row's own
  project or worktree goes stale. No test catches either.
- **Every control wears the macOS 26 style**, which linking against that SDK
  turns on. xcodebuild records a package's deployment target as the SDK it was
  built against, so the old floor of 14 kept the older style until the floor
  moved.
- **A segmented picker in that style is only as wide as its labels**, so each
  one asks for flexible sizing to span its row: ViewSegmentedAcrossRowTests.
- **An untinted icon in project settings is the system's grey**, not the
  theme's: that window follows the system appearance, and a dark theme's grey
  vanished on a light page. The sidebar keeps the theme's.
- **A missing project's badge is ringed in what the icon sits on**, the
  sidebar's colour in a row and the header's in the header, as a pane's state
  dot is. One fill for both drew a patch of sidebar on the header:
  WorktreeHeaderTests.
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
- **The agent and git colours are sections of their own**, `ui.states` and
  `ui.git`, read wherever a dot, a badge or a count is drawn.
- **libghostty takes no alpha**, so a terminal colour's is dropped on the way to
  it; the focus ring, drawn by the app, keeps its own. `cursor_text` and
  `selection_foreground` left empty are not sent, leaving the user's own Ghostty
  config or libghostty's default, which keeps each cell's colour.
- **The settings windows and dialogs stay out of the theme**, following the
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

# Appearance and window chrome

Themes, the focused pane, the window the app draws itself. Newest at the bottom.

- **Themes are hex strings**, so portability and user theme files come free.
  Cost: a light terminal means a light sidebar whatever the OS mode.
- **The window chrome is drawn by hand.** Recent macOS renders split-view
  sidebars as floating glass, and the AppKit split sizes children however it
  likes and exposes nothing.
- **Cost of that**: sidebar keyboard navigation has to be built, the split uses
  an underscored SwiftUI API, and each hand-drawn row needs an accessibility
  label reading its glyphs in order.
- **Both headers stand in for the title bar at the metric's height**, the band a
  hidden title bar keeps. Anything shorter, or anything but a header reaching
  into that band, and AppKit paints over it.
- **Nothing collapses the sidebar**, the traffic lights needing something under
  them.
- **Row heights are asked of one place**, by the row that draws it and by the
  sidebar counting a project's block. The two disagreeing puts the drop
  indicator in the wrong half.
- **One workspace window, `Window` scenes only.** Each surface is one `NSView`,
  and a second window would steal it.
- **Project settings is a `Window` too**, because a `WindowGroup` adds its own
  Close and AppKit gives Cmd+W to the first matching item, so that Close beat
  Close Pane and shut the app.
- **A settings window opens centred on the workspace's screen**, first tab,
  scrolled to the top. SwiftUI reshows the same window, so the close places it
  while nothing is on screen to jump.
- **The focus ring and the fade are the theme's.** A hairline in the selection
  colour was the wrong answer at a glance once columns made the question
  sharper, so both are theme keys.
- **The ring may be any colour, or empty for no line**; the fade dims every
  other pane towards the theme's background. The built-ins ring in their own
  blue, the selection colour being mixed to sit under text and reading as a
  smudge.
- **An unparsable colour falls back to the selection colour** rather than
  reading as off: a typo should cost the colour, not remove what the key sets.
  The fade clamps before a pane looks broken rather than unfocused.
- **The fade is a scrim in the theme's background, not view opacity.** A pane's
  surface is Metal-backed. Hit testing is off, so a click still reaches the
  terminal and undims it.
- **Cost of the scrim**: a light theme fades towards white, a wash rather than a
  dimming, and a theme turning both off has nothing left to say where the
  keyboard is.
- **The find bar floats, drawn as Ghostty draws its own**: a rounded panel
  lifted from the terminal under a hairline, the field in a well one step back,
  glyphs that light on hover.
- **The lift is smaller on a light theme**, which lifts towards black, or the
  sidebar's own lift reads as a grey slab over a white terminal. The well there
  carries its own hairline, being too near white to tell apart.
- **No shadow**: SwiftUI shadows every opaque part of a view, so one meant to
  lift the panel also blurred around the well inside it. The lift is the
  hairline's to give.
- **Not a strip across the pane.** A strip takes a row from every pane it is up
  in; a bar floating over the corner costs the terminal nothing.
- **No match count beside the field**, which Ghostty has, because the wrapper
  drops it (BUGS.md) and an empty slot would read as broken.
- **The theme sets the engine's search colours**, or it paints matches in its
  own defaults: matches in the theme's yellow, the selected one in the ring's
  colour, both with whichever of background and foreground is darker as their
  text, since white on yellow cannot be read.
- **That layer sits over the user's Ghostty config**, so a search colour in
  their file is read and then overridden, as their background is. The family
  stays allowed because it carries nothing else a surface reads.
- **A board card reads top down the way the sidebar does**, in a fixed two
  lines: the mark with its state dot, project and branch with the git badge
  right, then the tab title with the elapsed time on the same rail.
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
- **A project icon is tinted from a theme slot, not a hex**, so a theme change
  keeps it in step with the terminal.
- **The icon comes from a grouped palette read by shape**, not a menu of names
  read line by line: the menu is what held the list to a few dozen where the
  palette carries hundreds. Still keyboard-drivable.
- **Emoji are gone**, having looked out of place. A glyph is a symbol name or
  nothing, one rule read the same way everywhere, so a leftover neither masks
  the icon a repo's file names nor is written back into it. Cost: a project that
  had one draws the folder.

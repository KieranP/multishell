# Window chrome and controls

The hand-drawn window, its rows, marks and controls, and how they answer the
pointer. Newest at the bottom.

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
- **Settings is SwiftUI's `Settings` scene, project settings included**
  (settings.md). A `WindowGroup` would add its own Close, and AppKit gives Cmd+W
  to the first matching item, so that Close beat Close Pane and shut the app.
- **The settings window opens centred on the workspace's screen**, first page,
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
  in fixed-width digits so it does not jitter as it counts.
- **A board card has two fixed lines, read top down as the sidebar is**: mark,
  project, branch and git badge, then the tab title and elapsed time. A Failed
  card's dot leads the first line, before the mark.
- **The agent's name came off the card.** The tab title almost always repeated
  it, and the mark says what is at the prompt however the tab is named.
- **The tab title is one line, truncated, and the badge shares the branch
  line.** What a card said about itself used to move under a title that took a
  second line, and the eye could not find it twice in the same place.
- **The message block below stays one to three lines and optional**, so cards
  are not all one height. It is the occupant's words and the one thing on the
  card worth the room. Cost: a long command is cut off.
- **The settings window asks about removing a project itself**, or the dialog
  would be behind it.
- **The terminal font is picked, not typed**, some programming fonts not being
  marked fixed-pitch.
- **The UI font's family is a setting of its own beside its size**, so the
  chrome can match the terminal or editor font someone reads all day. Code,
  paths and commands keep the system monospace, and the settings window and
  dialogs keep the system font.
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
- **Picking the folder or no tint over a repository's icon is stored**, as
  `folder` and as slot -1, read as none: stored as nothing, the file's glyph or
  tint showed through, and the pick did nothing.
- **A missing project's badge is ringed in what the icon sits on**, the
  sidebar's colour in a row and the header's in the header, as a pane's state
  dot is. One fill for both drew a patch of sidebar on the header:
  WorktreeHeaderTests.
- **Each state's dot has a shape of its own as well as a colour**: done fills,
  idle is an empty ring, working is a fifth of the ring going round a faint
  track, waiting is a ring round a centre dot, and failed is an upright rounded
  square. The base themes' waiting is their selection blue, and the dots were
  told apart by colour alone, the Agents counts included.
- **Working's arc turns and waiting's ring pulses, by Core Animation** as the CI
  running ring turns, so neither costs the app a frame, and every glyph of one
  kind starts on a shared cycle so they move in step. Reduce Motion keeps both
  still; an empty board column's header never moves.
- **The working arc was picked over a half fill, a hollow ring, a sweep, a
  breathing dot, a triangle and an orbiting dot** (mockups, 2026-11-05). The
  half fill read as a level, and the breathing dot pulsed too like waiting.
- **Failed's square was picked over a diamond, a cross, a warning triangle, a
  stop octagon and a struck ring**, and idle's empty ring over a filled, small,
  dashed, dotted or missing dot (mockups, 2026-11-05). A filled grey idle shared
  done's shape, and the triangle is the row's mark for a failed stage.
- **A selected sidebar row is a wash with no outline.** The pane in front rings
  itself in the same blue, and two rings answered where the keyboard was twice;
  the sidebar never holds the keyboard, so an outline following it would never
  show. The base themes' wash went from 12% to 20% (18% light) to carry the
  selection alone, and the quick switcher's with it, taking its selection from
  the sidebar. A tab dragged over a row keeps its dashed outline.
- **Every built-in theme's wash reads at 1.25:1 or more on its sidebar**, the
  faintest the 18% light wash gives (View+RowSelectionTests). GitHub Light's
  source wash, 20%, gave 1.12:1 with no outline beside it, so it is 40% there,
  sidebar and switcher, departing from the published theme for that one key.
- **A chrome glyph button lights under the pointer as the find bar's do**: the
  area's full text over its `fill`, in a rounded square, on the sidebar header's
  buttons and sort menu, a project's +, the header and file bar's actions menus,
  the file bar's view menu, the Files panel's pages and toggle, the strip's plus
  and splits, and a tab's X, which takes the strip's `fill` for either kind of
  tab, a terminal tab's section having none. Nothing but the find bar answered
  the pointer before, and the sort glyph and the + only brightened. Rows stay
  still, a click answering with the selection wash; the + still brightens while
  its row is pointed at. Picked over a brightening alone and over the square
  with a wash on rows (mockups, 2026-11-05). `tab_bar` gained a `fill` for it
  and for a hovered tab. A button whose click can raise a sheet, picker, alert
  or close dialog, a tab's X and a terminal tab among them, unlights on its
  click, as what opens hides the pointer's exit. Hover is tracked on every move
  (`tracksHover`), not only at the edges, so a button unlit under a still
  pointer lights on the next move.
- **The Files panel's row for the file in front takes the sidebar's blue wash**,
  20% dark and 18% light, where its 6% fill was the faintest selection in the
  app. GitHub Light's takes its sidebar's 40%, every built-in's held to the
  sidebar's floor (FilesPanelRowTests). Cost: two blue washes, which worktree
  and which file, at either edge of the window. Picked over a stronger grey and
  the old 12% blue.
- **A head-cut path draws whole, a tail of about a dozen characters, or
  nothing**, eight times its text size wide: the header's path and a file tab's
  folder (`ReadableTail`). Squeezed further the header's drew one stray mark and
  held room the project and branch names were cut short for, and the folder drew
  a lone ellipsis (WorktreeHeaderTests, FileTabBarTests). A path shorter than
  that least draws whole wherever it fits. Cost: in a narrow header the path is
  only in the actions menu's Copy Path.
- **A renamed worktree's branch in the header gives way after the path and
  before the names**, at half their layout priority. At the spacer's it was cut
  to a few points while the header had room, and at the names' a long branch cut
  the project's name (WorktreeHeaderTests).

## Reviewed and left as is

- **A file tab's bar cut at its group's edge may still take a click past it**
  (round 1 of the narrow sizes review, 2026-11-05). Unproven: SwiftUI's hit
  testing past a clip could not be checked without clicking the window.
- **A hidden header path keeps one 6 pt stack gap** (same round): the empty view
  is still a child of the header's stack. Taking it back means splitting the
  stack, which moves the names' layout priorities for 6 pt. The file bar's
  folder carries its gap itself, as a name moving 6 pt there showed between
  tabs.
- **Modified or Branch in the view menu shows no help** (round 2): `.help` on a
  menu's section or picker could not be shown to reach a tooltip without opening
  the menu on screen, so it was left off rather than claimed. The switch on the
  bar keeps it.
- **A path shorter than the least is tested at a width the header measures for
  it** (round 2 asked whether the test reaches that case): with the "whole"
  option removed from `ReadableTail` it fails.
- **A state dot works out its own line widths** (round 2, 2026-11-05) rather
  than in `UIMetrics`: the dot is their only user, and the CI glyph's stroke is
  another design's, not a shared measurement.
- **A dragged collapsed project's preview may drop the turning arc** (round 3,
  2026-11-05). Unproven: SwiftUI's drag snapshot of an `NSViewRepresentable`
  could not be checked without driving the desktop.
- **Each lit glyph button holds its own hover**, `glyphHover` taking it as a
  value (round 4 of the design picks review): three are menus, heard from
  outside the menu, and the X and the splits hear it outside `disabled`, so a
  modifier holding it would be wrong for five of the nine.
- **A corner badge's ring is painted in its ground's colour, passed down**
  (round 14), `ringWash` now carrying a hovered tab's and a selected switcher
  row's: a ring cut out of the glyph would change every badge in the app, the
  sidebar's and the board's included, and could not be checked on screen.

### Asked both ways

- **`CenteredFlowLayout` caching its subviews' sizes**: round 1 of the design
  picks review asked for the cache, a layout pass measuring every button twice;
  round 3 asked whether a size could go stale under it. Kept: SwiftUI calls
  `updateCache` whenever the subviews change, a font change among them.
- **`AnimatedGlyphView.motion` takes a new motion** (round 2 asked for it, round
  3 to drop it, as no caller changes one today). Kept: a representable that
  ignores a changed input is a trap for the next caller, at a few lines.

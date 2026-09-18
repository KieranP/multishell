# Appearance and window chrome

Themes, the focused pane, the window the app draws itself. Newest at the bottom.

## Themes are hex strings

Portability and user theme files for free. Cost: light terminal -> light sidebar
whatever the OS mode.

## The window chrome is drawn by hand

macOS 26 renders `NavigationSplitView` sidebars as floating glass, and
`HSplitView` sizes children however it likes and exposes nothing. Cost: sidebar
keyboard navigation has to be built, `WeightedSplit` uses `_VariadicView`, each
hand-drawn row needs an accessibility label reading its glyphs in order.

Both headers stand in for the title bar at `UIMetrics.headerHeight`, 40 pt, the
band a hidden title bar with a unified-compact toolbar keeps; anything shorter,
or anything but a header reaching into that band, and AppKit paints over it.
Nothing collapses the sidebar, the traffic lights needing something under them.
A worktree row is `UIMetrics.worktreeRowHeight`, asked by both the row that
draws it and the sidebar, which counts a project's block off it to place the
drop indicator: the two disagreeing puts the indicator in the wrong half of the
block. The selected worktree's pane rows, `paneRowHeight` each, are counted the
same way.

## One workspace window, `Window` scenes only

Each surface is one `NSView`, and a second window would steal it. Project
settings is a `Window` too, because a `WindowGroup` adds its own Close and
AppKit gives Cmd+W to the first matching item, so that Close beat Close Pane and
shut the app.

Either settings window opens centred on the workspace's screen, on its first
tab, scrolled to the top. SwiftUI reshows the same window after a close -> the
close places it while nothing is on screen to jump, and becoming key is the
first point that knows which screen the workspace is on.

## The focus ring and the fade are the theme's

Which pane the keystrokes go to was a one-point line in the theme's selection
colour, drawn only inside a split. Columns make that question sharper, and a
line that thin is the wrong answer at a glance -> both signals are theme keys:
`focusRing` any colour, or empty for no line at all, and `inactivePaneOpacity`
fading every other pane towards the theme's own background. The built-ins ring
in their own blue rather than their selection colour, which is mixed to sit
under text and reads as a smudge as a line, and fade unfocused panes to four
fifths, legible without being asked for.

An unparsable colour falls back to the selection colour rather than reading as
off: a typo should cost the colour, not silently remove the thing the key was
setting. The fade clamps at a quarter, below which a pane looks broken rather
than unfocused.

The fade is a scrim in the theme's background colour laid over the pane, not
`.opacity` on the surface: a pane's surface is Metal-backed, and view opacity on
one is not something to rely on. Hit testing off, so a click still reaches the
terminal and focuses it, which is what undims it. Cost: a light theme fades
towards white, a wash rather than a dimming, and a theme that turns both off has
nothing left to say where the keyboard is.

## A board card's own lines are a fixed three

A card's tab title is one line, truncated, and the git badge sits on the right
of the line naming the worktree rather than on a line below it. Both are so that
the card's own lines are a fixed three: what a card said about itself used to be
buried under a title that had taken a second line and a badge that had taken a
line of its own, and the eye could not find it twice in the same place. The
message block below them is still one to three lines and still optional, so
cards are not all one height; that block is the occupant's words and is the one
thing on the card worth the room. Cost: a long command is cut off, where two
lines used to show it.

## The find bar floats, and the matches wear the theme

Drawn as Ghostty draws its own: a rounded panel lifted from the terminal under a
hairline, the field in a well of the terminal's own background one step back
inside it, and three glyphs that light on hover so they read as buttons. The
lift is the sidebar's on a dark theme and a third of it, `columnColor`, on a
light one: a light theme lifts towards black, and the sidebar's nine per cent
read as a grey slab over a white terminal. The well on a light theme carries its
own hairline, three per cent being too little to tell white from. No shadow:
SwiftUI's `.shadow` shadows every opaque part of the view, so one meant to lift
the panel off the text also blurred dark around the well inside it, and the lift
is the hairline's to give. Not a strip across the pane: a strip takes a row from
every pane it is up in, and a bar that floats over the corner costs the terminal
nothing. No count beside the field, which Ghostty has, because the wrapper drops
it (known-gaps.md); an empty slot would read as broken. The engine paints the
matches, and it would paint them in its own defaults, so the theme layer sets
its four `search-` colours: matches in the theme's yellow, the one selected in
the focus ring's colour, both with the darker of the theme's background and
foreground as their text, since a light theme's background is near white and
white on yellow cannot be read, so what the bar found is told from what the
shell printed in the theme's own voice and the selected match wears the colour
the app already uses for "here". The theme layer sits over the user's Ghostty
config, so a `search-` colour in their file is read and then overridden, as
their `background` is; the family stays on the allowed list because `search-`
carries nothing else a surface reads.

## A board card now reads in the sidebar's order, in two lines

The card used to open with the agent's name, which the tab title almost always
repeats, and put where the pane is on its third line. It now reads top down the
way the sidebar does: the state dot with `project › branch` and the git badge on
the right, then the tab title with the elapsed time on the same right-hand rail.
That drops the fixed three of the section above to a fixed two, and the agent's
name off the card; a pane running an agent under a tab named something else is
told apart by the tab name, which is what the user wrote. The message block
under them is unchanged. Cost: nothing on the card says which engine is at the
prompt, so a tab left with its default name is the only place that shows.

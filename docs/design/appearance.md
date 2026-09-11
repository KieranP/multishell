# Appearance and window chrome

Themes, the focused pane, the window the app draws itself.
Newest at the bottom.

## Themes are hex strings

Portability and user theme files for free. Cost: light terminal -> light
sidebar whatever the OS mode.

## The window chrome is drawn by hand

macOS 26 renders `NavigationSplitView` sidebars as floating glass, and
`HSplitView` sizes children however it likes and exposes nothing. Cost: sidebar
keyboard navigation has to be built, `WeightedSplit` uses `_VariadicView`, each
hand-drawn row needs an accessibility label reading its glyphs in order.

Both headers stand in for the title bar at `UIMetrics.headerHeight`, 40 pt,
the band a hidden title bar with a unified-compact toolbar keeps; anything
shorter, or anything but a header reaching into that band, and AppKit paints
over it. Nothing collapses the sidebar, the traffic lights needing something
under them. A worktree row is `UIMetrics.worktreeRowHeight`, asked by both the
row that draws it and the sidebar, which counts a project's block off it to
place the drop indicator: the two disagreeing puts the indicator in the wrong
half of the block.

## One workspace window, `Window` scenes only

Each surface is one `NSView`, and a second window would steal it. Project
settings is a `Window` too, because a `WindowGroup` adds its own Close and
AppKit gives Cmd+W to the first matching item, so that Close beat Close Pane
and shut the app.

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
`.opacity` on the surface: panes are `NSView`s, one Metal-backed, and view
opacity is not something both engines honour the same way. Hit testing off, so
a click still reaches the terminal and focuses it, which is what undims it.
Cost: a light theme fades towards white, a wash rather than a dimming, and a
theme that turns both off has nothing left to say where the keyboard is.

## A board card's own lines are a fixed four

A card's tab title is one line, truncated, and the git badge sits on the right
of the line naming the worktree rather than on a line below it. Both are so
that the card's own lines are a fixed four: what a card said about itself used
to be buried under a title that had taken a second line and a badge that had
taken a fifth, and the eye could not find it twice in the same place. The
message block below them is still one to three lines and still optional, so
cards are not all one height; that block is the occupant's words and is the
one thing on the card worth the room. Cost: a long command is cut off, where
two lines used to show it.

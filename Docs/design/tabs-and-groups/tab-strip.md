# The tab strip

How a strip runs out of room, its buttons and New Tab menu, and what each tab
draws. Newest at the bottom.

- **A strip out of room scrolls and says which way there is more.** Every tab is
  drawn at one width from the room and the count, sharing the strip up to a cap
  and shrinking together as more arrive.
- **They stop at a floor**, below which the icon, the title and the close button
  run into each other and into the next tab. Past the floor the strip scrolls
  and clips.
- **The floor is never under what the active tab draws besides its title, plus
  two characters of title.** Scaled from the font size alone, it left the active
  tab almost no title at UI sizes 10 to 12
  (`aTabStripsMeasuresHoldWhatTheyDrawAtEverySize`).
- **A group minimum is not the answer**, which is where this started: it would
  have to grow with the number of tabs, and a worktree with eight could no
  longer sit beside another. The floor belongs to the tab.
- **The end with tabs past it carries an arrow, in a gutter outside the
  scroller.** Over the tabs it would take the click meant for the tab under it,
  or sit there looking like a button and doing nothing.
- **The arrow finishes the tab that end clips**, else moves on to the first
  whole tab past it. Counting in whole tabs left it dead over a half-shown tab,
  the arrow being drawn from the same half point.
- **It was a fade first**, on the argument that a fade cannot be mistaken for a
  control, and the fade was too quiet to read as anything at all.
- **Both gutters keep their room whether an arrow is drawn or not**, so tabs do
  not shift under the pointer as one end runs out, and the reserved room is what
  the viewport is measured as.
- **A strip with no room for both gutters and a tab has neither**, or two arrows
  and nothing to scroll would be drawn over the group beside it.
- **New Tab sits outside the scroller too**, so a full strip cannot push it out
  of reach, and the tab turned to is scrolled into view.
- **A scrolling strip has no spacer**, its gutters and New Tab set straight
  against the scroller. A scroller and a spacer are both infinitely flexible,
  and the stack would divide the strip between the two.
- **The two splits sit in the same gutter**, on the strip rather than in the
  pane, where a button over a terminal would take a click meant for the shell.
- **A narrow strip keeps New Tab alone.** A group can be dragged below what the
  three buttons take, so the splits are shown only above a threshold.
- **That threshold asks for the buttons, both gutters and a whole tab besides.**
  Counting only a tab buys the splits by leaving a scrolling strip with no
  arrows, the one thing arrows are there to prevent. `UIMetricsTests` writes the
  widths out.
- **Asked of the width unconditionally**, not of whether the strip scrolls,
  which is decided from the room this leaves: the two would chase each other.
- **Costs**: three buttons of gutter rather than one, so a strip shows a whole
  tab later; a group under the threshold offers the splits on its menu and
  keystrokes alone; no auto-scroll while a tab is dragged near an end, so a
  reorder reaches only the tabs on screen; and a strip whose tabs differ widely
  in width is the one shape where the shuffle could cross a boundary twice.
- **A wheel over the strip scrolls it sideways.** A horizontal scroll already
  reached the scroller, so a trackpad worked from the start and a mouse, which
  turns one way, did nothing.
- **The turn is redirected rather than counted.** A catcher answers hit-testing
  only for a scroll whose vertical beats its horizontal, and hands the strip's
  scroller a copy with the vertical deltas moved into the horizontal fields. So
  clicks, drags and a sideways scroll reach the tabs untouched, and the pixels,
  the momentum and the rubber band stay AppKit's.
- **Copied rather than built**, so the phase, momentum and precision it arrived
  with are kept. A turn that goes sideways partway through is passed on
  unchanged, a scroll being routed by its first event.
- **The swap writes each delta field once, from the vertical alone, lines
  first.** The fields are coupled, so reading each and adding counted a wheel's
  notch twice, while a trackpad's points survived only because the line write
  had wiped them.
- **A diagonal turn moves the strip by its vertical alone**, the horizontal
  being the smaller on that branch and dropped rather than mixed in.
- **Two halves, because neither placement can do the job alone.** Inside the
  scroller the catcher is hit-tested and never called, a scroller taking every
  scroll over its own content first. Outside, it cannot find the scroller
  either, SwiftUI flattening the tree, and climbing from there took the
  sidebar's, so the wheel scrolled the sidebar. So a marker inside the content
  hands the scroller over, the one place the enclosing-scroller lookup is exact.
- **Stepping whole tabs came first** and read as jumpy: an arrow is a click and
  can move a tab at a time, a wheel is continuous and cannot.
- **The strip's plus is a menu**: New Shell Tab and a New Tab item per agent
  found on the login shell's PATH, the custom command among them once one is
  typed.
- **Every item says what it starts**, which the plain plus could not: it ran the
  new-tab shortcut, whose answer turns on the project's auto-start setting, so
  the same click started a shell in one project and an agent in the next.
- **The shortcut itself is unchanged**, and it and its File menu item are the
  only ways left to ask for the auto-start answer by hand. The first tab a
  worktree opens by itself still gets it on select, and the create setting's
  answer on create.
- **The items open in the group the menu sits in**, as the split buttons do, so
  a click never acts in the group the keyboard happens to be in.
- **Every item's icon is a rendered image**, the shell's terminal glyph as well
  as the agents' marks: the shell's item as a symbol label drew no icon. The
  glyph is scaled into the marks' square, being wider than it, since the
  renderer clips what a tab lets spill over.
- **The list is held on the model**, rebuilt when detection answers or the
  custom command is edited: a menu's content is built with the view around it,
  and every group has one.
- **Before the login shell has answered it offers the shell alone**, rather than
  a catalogue of agents the machine may not have, and fills in when the scan
  lands. A typed custom command is listed from launch, having no scan to wait
  for.
- **The plus draws its own chevron**, small enough to read as a mark on it
  rather than a second glyph, which makes the button wider than the splits
  beside it.
- **Its insets are equal, as a split's are** (REVERSAL, 2026-11-05). They were
  unequal, the chevron 4 pt nearer its edge, since a chevron's ink is narrower
  than its box and a split symbol's wider, so equal gaps between bare glyphs
  read as unequal. The lit square made the button's own edges visible, and the
  chevron sat cramped against its right side. Cost: the gap to the first split
  reads a little wider at rest.
- **AppKit's own indicator is hidden**, sitting where this one's spacing cannot
  reach it, and the glyphs sit on a painted frame, a menu being hit-tested by
  what its label draws.
- **It is the plain button style, not the borderless one**: that is an AppKit
  button, which takes a single image from its label and draws it at the leading
  edge, so the chevron vanished and the plus sat in the corner of a wide blank.
- **A rename from the command line leaves a name field open on another tab**, so
  a script naming one tab does not throw away what the user is typing into
  another's (`renamingATabLeavesTheFieldOpenOnAnotherAlone`).
- **A file tab sits in the strip beside terminal tabs**, the same width rules,
  drag and reorder, its order and theirs one order per group. files/file-tabs.md
  has why it never leaves its worktree and why the splits disable on it.
- **A file view reports its own focus**, a surface's report reaching the store
  only for a pane, so a click into one in another group moves Cmd+W and the
  menus there; the reconcile hands it the keyboard as it would a pane.
- **A reported title is drawn without an agent's leading status glyph**: Claude
  Code's `✳` and its working `◐ ◑ ◒ ◓` (2.1.318, read off a live tab), Gemini
  CLI's `✋ ⏲ ◇ ✦` (read in 0.66's bundle) and braille spinner frames, each only
  when a space follows. The mark and its state dot already say it, and at the
  strip's shared width it took two of about twelve characters. Trailing blanks
  go too, Gemini padding its title to 80. The strip, the sidebar, the board, the
  switcher, a banner and Debug Info draw it so; the command line reports the
  title raw. Cost: a glyph an agent adds later shows until it is listed.
- **A shell titled with a directory inside its worktree is drawn relative to
  it**, `src/routes`, and as a plain shell at the root: the row already sits
  under that worktree, and `…/demo/acme-worktrees/feat-auth` said nothing new.
  Read from the title alone, in the three forms shells write (whole, from `~`,
  `…/` and the last parts), since the directory reports stop at the surface.
  Cost: a `…/` title is read against the worktree's own last parts, so another
  folder sharing them, or one inside the worktree named as it is, is drawn from
  the wrong root. The title kept only its last parts; nothing says which.
- **Every group's shown tab has its X, and any tab has one under the pointer**,
  over the strip's `fill`. A background tab closed by middle click alone, and
  another group's shown tab needed a click first. The X's room is kept while it
  is not drawn, so a title never shifts; the floor already counted it. Picked
  over the X on hover alone and over an X in the mark's place, which would have
  taken the mark's clear-state click (mockups, 2026-11-05).
  `TabCloseButtonVisibility` holds the rule.
- **The shown tab has hairline sides and an open bottom**: the strip draws its
  bottom hairline under the tabs, the shown tab's fill covering it, and the
  separators between the other tabs went. Fill alone stood off the strip at
  1.11:1 dark and 1.07:1 light, so with two groups which tab each showed was
  hard to see. Picked over a 2 pt line on each shown tab and a strip stepped
  further from the terminal. Cost: in Light the sides are as faint as the
  separators were; the arrows and the plus paint short of the hairline.
- **A worktree with no tab shows a placeholder**: its name, and a button for a
  shell and one for each agent the New Tab menu lists, under the menu's own
  labels. It was a blank area with no way to the plus, reached on every select
  with opening a terminal on select off and after the last tab closes. Picked
  over an empty strip with its plus, which would need a strip with no group
  behind it. Cost: the buttons repeat the plus menu, and the area takes no
  dropped tab. Each button is edged in `detail`'s new `border`, as the mockup
  drew it: its block alone stood under 1.1:1 off the ground in six built-ins.
  The edge stands 1.1:1 off it in every one (PlaceholderButtonTests), Dracula's
  in its current-line colour and Nord's in nord2, their header borders matching
  their blocks. A button wider than the area truncates its label.

## Reviewed and left as is

- **A tab that slides under or away from a still pointer keeps its hover until
  the pointer moves** (round 1, 2026-11-05): `tracksHover`, on
  `onContinuousHover`, hears only the pointer's own moves, so after a close or a
  reorder the X and wash follow the next movement. Unproven on screen, and the
  next move corrects it. A strip button or the sort menu, once chosen from, may
  stay lit the same way (round 2), as may the header's actions menu once an item
  opens a sheet (round 22).
- **A click on the plus's bottom half point may miss its menu** (round 3,
  unproven): the label paints short of the strip's hairline, and a menu is
  hit-tested by what its label draws. Half a point, not checked on screen.
- **A dragged shown tab shows the strip's bottom hairline through it** (round
  2): the tab fades while it is dragged, its fill with it, which is the fade
  saying it is in the air.
- **A tab's hover is held by its face, whose body runs again on each enter and
  exit** (round 2): a few lookups for one tab, and the badge's ring needs the
  same wash the face draws.
- **The shown tab's side beside a hovered neighbour reads only as the wash's
  edge** in Nord and Multishell Light (round 6), about 1.2:1, the side's own
  line matching the wash.
- **The no-tabs caption's choice is read in the view from
  `AppModel.offersAgentTabs`** (rounds 4 and 6, asked both ways): a type
  wrapping the lookup is the second name translation.md rules out, and the
  decision itself is the tested property.
- **A shown first tab's leading side sits against whatever comes before the
  strip** (round 8): the sidebar's edge or a group's divider. A debug build's
  screenshot in both base themes showed it reading as one line (2026-11-05).
- **Every strip part that paints calls `stripPaint`** (round 13) to stop short
  of the bottom hairline, rather than the hairline lying over the parts with the
  shown tab painting over it: the shown tab sits in a scroller under any overlay
  the strip draws.
- **The placeholder's buttons read the New Tab menu's keys** (round 4): they are
  its items, the same act in the same words, which translation.md lets one key
  carry.
- **A tab's name field starts from its shown title** (round 1, 2026-11-04), and
  a field abandoned by a click elsewhere stores what it holds, as it stored the
  raw title before. The field starts from what the tab says.
- **A tab face looks its worktree up for every shown title** (round 2,
  2026-11-05): one search over a few dozen worktrees per tab drawn, and the face
  holds no worktree to pass in. The pane rows, board and switcher pass it.
- **A directory title is matched by its exact spelling** (round 3, 2026-11-05),
  so a `cd` typed in another case, or through a symlink, keeps its full path.
  Folding case would match wrong folders on a case-sensitive volume, and
  resolving links means reading the disk for every title drawn.
- **The terminal and file tab faces each derive `isShown`, the palette, the text
  colour and the title weight** (2026-11-12). Three one-line rules; a shared
  type for them would add more than it removes.
- **A status title whose text starts with a combining mark loses the mark** with
  the glyph and space before it (2026-11-12). No agent's status starts with one.

# Known gaps

What is unverified or unbuilt, with the fallback where there is one.

## Known gaps

- Release bundle runs only on the machine that built it: libghostty finds its
  terminfo through `Bundle.module`, which looks at the app root then an
  absolute path inside `Apps/macOS/.build`, never `Contents/Resources`, so
  elsewhere `TerminalController()` traps on the first terminal. Fix = build
  with Xcode or a patched libghostty-spm. Same path is why a bundle installed
  from a worktree stops working once that worktree is removed: install from
  the checkout, or rebuild after removal.
- Ghostty engine's path untested, its zsh chain checked only against a
  stand-in bootstrap. Click-to-move works there and nowhere else, and not on
  the later lines of a multi-line buffer.
- Linux never compiled, locally or in CI.
- Notifications settings page never seen on screen: the toggles, the caption
  under them, the six-tab band in a 560pt window. SettingsPageSizeTests holds
  this page's height under the window's own, so what is left is how it reads
  rather than whether it runs off the bottom. The band is measurable by
  nothing, SwiftUI drawing it outside the AppKit hierarchy; if it clips, raise
  the width in SettingsView. Caption and the help behind each (i) are strings
  in NotificationSettings.
- Agent settings is the one page nothing holds: its `onAppear` refresh reads
  the machine, so the page is as tall as whatever is installed and a test
  would be measuring a laptop. Measured headlessly with the refresh taken
  out, it is 260pt with no agent's hooks installed, 357 with one, 481.5 with
  four and 550.5 with all five, so the 600pt window now covers every case
  this developer can produce. A sixth supported agent would put it over
  again, and nothing would say so; fix then = the hooks rows want their own
  scroll.
- The 600pt settings window has not been seen on screen. It is the height
  the tallest page needs, so General shows 159pt of rows above 441pt of
  nothing, and whether that reads as roomy or as broken is a question for
  the screen. Fix if it reads badly = the tall pages scroll and the window
  goes back to about 480.
- Project settings' Hooks tab wants 973pt in a 600pt window, so its last
  editors are below the fold with nothing saying so. Six monospaced editors
  were never going to fit a window the other pages can share, and
  SettingsPageSizeTests records this one as deliberate so the next page to
  overflow is not lost in it. Every other page fits, Project General closest
  at 581.5.
- Directory check before a click starts a shell runs on the main thread, so a
  network volume that has gone away blocks until the mount times out. Polling
  paths' checks run off it.
- A file list a new worktree is given has no timeout, unlike a hook: runs
  until done or the pane's Cancel, which lands between paths.
- Drops reach SurfaceFrame because AppKit walks up from an unregistered engine
  surface to the frame that is registered: documented for the registration,
  undocumented for the search order, so if either engine ever registers a
  dragged type the frame stops seeing drops. Checked only by hand. Same walk
  carries a dragged tab past a surface to the SwiftUI band over it,
  SurfaceFrame being registered for files and promises and not for
  `io.multishell.tab`; if a band never lights, fallback = register the tab
  type on the frame and answer it there. Every column's tab strip takes a tab,
  and the sidebar's worktree rows do; nothing else.
- Tab-group drawing unverified on screen: whether bands appear as a tab
  crosses a terminal area, whether the insertion line lands in the right
  strip, how an unfocused column reads, whether a strip's scroll arrows read
  as "more tabs this way" better than the fade they replaced. Store, model and
  wording tested; drawing not. Cost of drawing only from what the pointer is
  over: bands are not on screen until the tab reaches a terminal.
- Whether a SwiftUI overlay composites above an engine's surface is unverified
  for Ghostty, whose surface is Metal-backed: the focus ring has always been
  drawn that way, and now the unfocused-pane fade too. If neither appears,
  both are silent rather than wrong, and the fade would have to become a view
  inside SurfaceFrame the way its drop highlight is.
- A scrolled tab strip does not auto-scroll while a tab is dragged near its
  end, so a tab cannot be dragged past the visible tabs: reordering reaches
  only what is on screen, and a tab off the end cannot be dropped on.
  Auto-scroll needs the drop's own pointer position, a repeating step, and the
  strip's `ScrollViewProxy` reaching the drop delegate.
- Reordering inside one column happens as the pointer passes each tab, not on
  release; see TabShuffle and `AppModel.shuffleTab`. Unverified at the edges: a
  strip whose tabs differ widely in width could in principle move a tab back
  and forth across one boundary, the tab landing under the pointer being what
  stops that.
- Agents board drawing unverified on screen: whether a card reads at the 208pt
  column floor, where the worktree name and the git badge now share a line and
  the name is what gives way, whether a partial column at the edge reads as
  "more this way" without the arrows a tab strip has, whether a vertical
  scroll per column nested in the board's horizontal one feels right to a
  trackpad, whether the Dock badge appears at all under this build's signing.
  If the partial column does not read, fallback = the tab strip's: an arrow in
  a gutter at each end that has cards past it, from `TabStripLayout.Edges`.
  Two known divergences from the mockup: columns are full height rather than
  hugging their cards, which is what lets each scroll on its own; and the View
  menu item's position within that menu is AppKit's to decide, being added to
  the standard group.
- While the Agents board is up, what acts on a pane does nothing, but Open in
  Editor and New Worktree still act on the selected worktree, and no sidebar
  row draws as selected then, so those two have nothing on screen naming their
  subject. Left because neither is destructive; fix = route them through
  `worktreeInView` as the pane commands are.
- Sidebar keyboard navigation and a shortcut to focus the filter are not
  built. No view tests, and the accessibility labels have not been read with
  VoiceOver.
- Existing-branch picker lists local branches only, so a remote-only branch is
  created as a new one based on its remote. A decision, not a defect.
- `.multishell.json` is read from the project path, which for a bare
  repository holds no checkout.
- Neither agent-flags row has been seen on screen: the CLI Flags field under
  the agent picker in Settings > Agents, and the CLI Flags override in a
  project's Agent tab. The value they write and the command line it builds are
  tested; the rows' width, and how an empty one reads with no prompt text in
  it, are not.
- The placeholders an agent's flags may use are documented nowhere a user can
  reach: the settings rows name `{{branch}}` as an example, and the rest live
  in `AgentPlaceholder` waiting for a documentation site.

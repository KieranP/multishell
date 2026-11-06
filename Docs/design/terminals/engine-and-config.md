# Engine, input and Ghostty config

The embedded engine, how input reaches it, and what of a user's Ghostty config
it reads. Newest at the bottom.

- **A user's Ghostty config is the middle of three layers**: this app's terminal
  defaults first, their file over them, the theme over both.
- **So their file decides cursor, scrollback and padding**, and font family
  while the font row says System monospace, and cannot decide the colours the
  chrome is painted to match or the font size a settings row owns.
- **Keybinds arrive as written**, less the app's own combinations and the keys
  it releases, unbound by name, so a binding they put over a menu item is theirs
  no longer.
- **Both places the engine reads on a Mac are read, under both names**, in its
  own order: `config` then `config.ghostty`, the XDG one then app support, each
  later file having the later word. The XDG variable is not read, an app the
  Finder launched not being given it. Read when the first terminal opens and
  each time the app comes to the front, the file being edited in another app;
  only a change is handed on.
- **Their `config-file` includes are followed here**, in the engine's order:
  each after the whole file naming it, a relative path from beside that file,
  `?` for one that may be missing, a file already read skipped. Left to the
  engine they would resolve from the temp directory the merged text is in.
- **A line ends at `\n` or `\r\n`**, as in Ghostty. Swift reads `\r\n` as one
  character, so a CRLF file split on `\n` was one line: its includes were lost
  and every key after the first rode through the allow list behind it.
- **The merged text reaches the engine through a file under the temp
  directory**, libghostty reading config from nothing else. The file goes the
  moment it is read, so no copy of the build leaves one for another to sweep.
- **A line the engine refuses costs that line, not the file**, as in Ghostty.
  The wrapper before it refused the whole file over one complaint, which the app
  undid by blanking lines and retrying; built here, the base goes over as is.
- **Each refusal goes to the unified log**, category `ghostty`, its line
  numbered in the merged config: the app's defaults, the user's settings, then
  the app's layer.
- **A config that could not be loaded at all is tried again**, at the next
  activation or theme change, and logged. The runtime keeps the text libghostty
  runs apart from what it was offered; recording the offer first skipped every
  retry until the file changed again.
- **This is not a corner**: the embedded build is not the Ghostty a user runs,
  and each carries keys the other lacks.
- **A user's config is read through a list of what is allowed**, not a list of
  what to refuse. The keys worth refusing are about what runs and what a window
  is, the kind a release is likeliest to add, so a refusal list is one release
  behind where an allowance list only ever misses a nicety.
- **Ghostty 0538f75 bore that out.** It added `vt-window-resize-allowed`, which
  lets a program resize the window, and the key stayed out with no edit here.
- **What is allowed is families that can only draw or drive a surface**, plus a
  short list named one at a time. Its only platform-prefixed keys are the option
  key, which a surface reads, and auto secure input, which the app reads back.
- **A family also carries a rename**: a limit key that was split in two keeps
  every spelling whichever build is pinned.
- **What is left out is chrome that does nothing in an embedding**, and the keys
  that would take a decision the app has already made: the command and the input
  that reach the child, the working directory, the title, the integration the
  prompt marks come from, and holding a surface open after its shell has gone.
- **The environment and theme keys are left out too**: the app gives each child
  the variables that name its session, and ships no themes directory, painting
  its own theme anyway.
- **Cost: a key we have not thought about is ignored in silence**, and nothing
  says which lines of a user's file did not count.
- **A key the command line presses is a key event, not text**: a US keyboard's
  key code and modifiers, with the text the current layout gives that key, as a
  real press carries, so libghostty encodes Ctrl+C, Escape and the arrows as a
  keyboard would. Option types the layout's character unless the user's
  `macos-option-as-alt` makes it Alt, asked of the surface for each key. Its
  modifier keys go down before it and up after, as a keyboard sends them:
  libghostty keeps the last modifiers it saw for the mouse, so a Cmd left held
  kept a link under the pointer lit (`GhosttyKeyInputModifierKeysTests`).
- **Cost: a key is named by its place on a US keyboard**, so on another layout
  `a` types what that key types there. `GhosttyKeyInputControlKeyTests` runs
  only under the US layout.
- **Ghostty keybinds are unbound by name**, not cleared wholesale, which also
  removes word movement and delete-to-start.
- **Names and menu items come from one shortcuts table**; a shortcut in only one
  list was a keystroke that worked everywhere but a pane.
- **Clipboard binds stay bound**: in a pane the copy key is Ghostty's copy of
  the terminal's selection, and unbinding it hands the keystroke to a menu item
  with nothing to copy.
- **One terminal engine, embedded and named outright.** It owns the pty, the
  renderer and the config, so a pane's surface is Metal-backed.
- **Cost of one engine**: a pinned build that misbehaves has nothing to fall
  back to, the unfocused fade is a scrim rather than view opacity, and nothing
  tests the host against a real shell, a test's surface running `/bin/sleep`.
- **The app talks to libghostty's C API itself**, after Ghostty's own macOS app,
  built from source with our patches (develop/dependencies.md).
- **libghostty draws on its own thread**, paced to the display the window is on,
  so the view keeps no display link; a wakeup from any thread only ticks the app
  on the main one.
- **A command key goes to the menus before the terminal**, and is typed only
  when AppKit offers the same event again, which it does when no menu took it.
  The event's timestamp is the identity, events comparing no other way. A key
  libghostty binds goes to the pane first, which is why the menus' keys are
  unbound.
- **A right click goes to the program**, and nowhere else where the program does
  not take it: the app has no context menu over a pane. Right and middle clicks
  take the keyboard as a left one does, or a paste landed in one pane and the
  typing stayed in another.
- **A click on a pane in a window not in front takes the keyboard too.** AppKit
  spends that click on bringing the window forward and never delivers it, so a
  split's other pane kept the keyboard.
- **A command key's release is caught on its way through the app**, AppKit
  delivering it to no view, and sent only to the pane with the keyboard in the
  window it came from.
- **One monitor for the app catches both**, handing the release to the window's
  first responder and the click to the pane it hit. A monitor per pane ran every
  click past every pane's hit test.
- **A program asking whether the terminal is light or dark is told the theme's
  answer**, the view's appearance following the app's theme, not the system's.
- **Secure keyboard entry is on while a pane at a password prompt has the
  keyboard**, which libghostty spots by the program turning echo off; the
  `toggle_secure_input` keybind flips it for that pane. Off altogether where the
  user's `macos-auto-secure-input` says so, as accessibility and snippet tools
  need. It is one switch for the whole Mac, so every enable is balanced and it
  is let go while another app is in front.
- **Cost: the pane shows libghostty's lock cursor at the prompt**, not whether
  macOS took the switch, and a keybind toggle shows nothing.
- **The right-hand Option key is told apart**, so `macos-option-as-alt = left`
  leaves the right one typing accents.
- **An astral character an input method commits in two UTF-16 halves is joined
  before it is sent**, as Ghostty's app does. The lead half commits as empty
  text, and that empty commit let the key type its own character ahead of the
  pair (`aLeadSurrogateCommittedAloneSendsNothingUntilItsPairArrives`).
- **The runtime is built on first use**, the theme held until there is one, so a
  copy that hands over at launch never starts one.
- **Each pane's view holds the runtime**, so libghostty's app is freed after the
  last surface made in it. A view holding only the runtime's secure input let
  releasing the host free the app before its surfaces, a crash
  (`aSurfaceViewKeepsTheRuntimeItWasMadeInAlive`).

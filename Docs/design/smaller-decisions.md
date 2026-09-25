# Smaller decisions

What has no other file to go in. Newest at the bottom.

- **Install Command Line Tool is the one thing run as root.** The two paths go
  in as Apple event parameters to a handler in a constant script, never
  interpolated into it, and the script quotes them with AppleScript's own form.
- **Interpolating and escaping by hand escaped for the shell, not for
  AppleScript**, so a quote in the home path ended the literal and ran the rest
  as root. Costs: four-char codes Swift does not import, and main-actor-only
  components.
- **Return presses a dialog's lead button, Escape its Cancel.** SwiftUI gives a
  cancel-role button Escape on its own but binds Return to nothing, so the
  confirmations could only be answered with the mouse.
- **A confirmation that removes something is an `NSAlert`, not a SwiftUI
  dialog.** `.defaultAction` answers Return and repaints the button as the blue
  default, losing the red that says what it does, and no styling brings it back.
  AppKit is stricter still: `layout()` takes Return off any button with
  `hasDestructiveAction`, which is how the platform keeps a destructive action
  from being the default. `DestructiveAlert` builds the alert and puts the key
  back after presenting, the last layout there is. AppKit draws a default button
  in the accent colour whatever its role, so `DestructiveAlert` paints the bezel
  `.systemRed` there too, and again a turn later: the sheet lays out once more
  on its way up, and until it does the button opens blue and only flashes red as
  it is pressed.
- **macOS 27's alert button keeps no bezel colour**, and draws a destructive one
  red itself, the one taking Return solid in a key window and the rest pale; so
  the test reads the drawing there, offscreen.
- **Clearing the pending value takes the sheet down with it.** A worktree
  removed outside the app clears `pendingWorktreeRemoval`, and a sheet left
  standing would confirm a removal on a path git no longer knows (worktrees.md).
  The `destructiveAlert` modifier drops the answer when that happens, rather
  than reading it as a Cancel.
- **The shared-settings question stays a SwiftUI dialog**: nothing it offers is
  destructive, so the blue default is right, and Return declines. Its other
  button runs what a repository committed, nobody asked for the question, and a
  keystroke meant for the window behind must not be what trusts it.
- **The quit alert is AppKit's own.** `NSAlert` gives Return to its first
  button, and Escape only to one titled exactly "Cancel", so the app sets the
  key equivalent by hand: a translated title would leave that alert with no way
  out.

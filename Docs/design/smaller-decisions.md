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
  cancel-role button Escape on its own but makes no destructive button the
  default, so Return answered nothing in the confirmations. Each dialog with a
  choice to make now names its default, the worktree one taking the first of
  `choices`, so the merge state decides which. The error alert's forced branch
  deletion answers Return too: it is the one thing that alert offers, and a
  removal the user already confirmed is what put it there.
- **A destructive button takes a plain Return, not `.defaultAction`.** Both were
  watched on a screen: `.defaultAction` answers the dialog and repaints the
  button as the blue default, losing the red that says what it does; Return with
  no modifiers, `KeyboardShortcut.dialogDefault`, answers it and leaves it red.
- **The shared-settings question is the exception**: Return declines. Its other
  button runs what a repository committed, nobody asked for the question, and a
  keystroke meant for the window behind must not be what trusts it.
- **The quit alert is AppKit's own.** `NSAlert` gives Return to its first
  button, and Escape only to one titled exactly "Cancel", so the key equivalent
  is set by hand: a translated title would leave that alert with no way out.

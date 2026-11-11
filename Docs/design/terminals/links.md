# Clicked links and the pointer

What a link clicked in a pane opens. Newest at the bottom.

- **The pointer is what libghostty asks for**, an I-beam over text and a hand
  over a link, hidden while typing where the user's config says so, bar the hand
  below.
- **Cmd shows the hand and Cmd+click opens a link a program holding the mouse
  printed**, as libghostty does in a plain shell; without Cmd, no hand.
  libghostty looks for no link while a program such as Claude Code holds the
  mouse, and a mouse report carries no Cmd, so the app reads the word under the
  pointer and its row each time the pointer reaches another cell with Cmd held.
  Where that reads as a web address, a path, or a file name the highlighter or
  macOS knows, an app's excepted, libghostty's arrow turns into the hand, never
  a shape the program asked for, and a Cmd+click opens it by the clicked-link
  rule without reaching the program, unless a drag or Cmd let go left it first.
  A bare name drops its `:12`, which the rule would read as a URL's scheme.
  Cost: the pattern is the app's guess, `and/or` reading as a path and
  `console.log` as a file, and text redrawn under a still pointer is judged at
  the next move. An OSC 8 link's target is not readable here, so its text is
  opened.
- **A pane without the keyboard is handed Cmd's changes** by the app's event
  monitor, flagsChanged reaching only the first responder, so the hand comes and
  goes there too. A pointer dragged past the pane's edge is over no link,
  libghostty reading the edge cell's word there.
- **Reviewed and left as is, for that hand**: a Cmd press under a pointer that
  has not moved since the pane appeared judges libghostty's last position;
  sending it the pointer first would report a motion to the program on every
  Cmd. No test reaches the word and row reads, a test pane's command never
  running, so a pane holding the mouse is checked by hand.
- **A link clicked in a pane opens only for the web, mail, a text file in the
  editor, or a folder, image, PDF, audio, video, archive or Office file in its
  default app**, judged by what its path resolves to, refused with a beep
  otherwise. Left to libghostty, `open` ran whatever target a program printed,
  `file:///System/Applications/Calculator.app` among them, and from `ad97d33` it
  opens no link from a pane's text at all (`GhosttyLinkRuleTests`).
- **It is judged through `runOnDispatch` and acted on after the click**: its
  stats can hang on a share that stopped answering, and libghostty reports the
  click holding the pane's renderer lock, which a tab opened or focus moved
  takes again. One answered after a later click, or after its pane closed, opens
  nothing, so a slow one neither holds back nor overtakes the next. A link
  clicked again while still judged is not judged again, each try parking a
  thread, and its answer goes to the latest click. Cost: a click on such a share
  does nothing, not even beep.
- **An OSC 8 hyperlink opens only a file on this Mac**, judged as any other, and
  beeps for a web or mail target. Its target is not the text the pane shows, and
  nothing here shows it before the click, as Ghostty's app does in a banner on
  hover; a local file cannot be someone else's site. Agents, `ls --hyperlink`
  and gcc print their paths this way.
- **A `file:` URL opens only for this Mac**: no host, `localhost` or the Mac's
  own name, which `ls --hyperlink` and `rg` write. A relative one names no file.
- **What a default app may open is a list of kinds, not a list of refusals**:
  the refusals missed a Finder alias and a `.fileloc`, whose target Launch
  Services opens, Calculator for one pointing at it, a `.shortcut` Shortcuts
  imports, a `.dmg` it mounts and a `.prefPane` System Settings installs. A
  bundle is not a folder here. Archives and Office files open, but not a kind
  macOS counts as runnable, a `.jar` or a macro-enabled `.docm`. Cost: those, an
  `.xcodeproj` and an unnamed kind beep.
- **A relative path is looked for in the pane's directory, then under the
  repository root**, the nearest folder up holding `.git`, and there without a
  leading `a/` or `b/`, the sides `git diff` names files by. libghostty joins a
  relative path to the shell's reported directory only where the file is there.
  A shell that reports none, sh or nu, leaves where the pane started. One the
  pane's directory holds wins, a folder named `a` included.
- **A compiler's `Sources/A.swift:12:5` opens the file**, a `file:` URL's too,
  when no file has that name, libghostty's pattern taking `:` as part of a path.
  The line is not passed on, and neither is what follows it, `rg`'s
  `src/main.rs:12:fn`. A bare `A.swift:12:5` is no link, libghostty's pattern
  wanting a `/`, except under Cmd where a program holds the mouse.
- **`$HOME/…` and `$PWD/…` expand**, libghostty marking any `$VAR/` path; the
  app knows only these two as the pane's shell has them.
- **A file is text if its type says so or its first 8 KB are UTF-8 with no zero
  byte**: macOS has no text type for a `.rs`, a `.go` or a `Dockerfile`, and
  calls a `.ts` an MPEG-2 video. So a location file written as XML opens as
  text, in the editor, never through Launch Services.
- **A text file opens in the editor Open in Editor uses**, whatever its mode: an
  application is handed the file, a terminal editor opens it in a tab in the
  pane's worktree, and a custom command reads `{path}` from
  `MULTISHELL_FILE_PATH`, the worktree's variable naming a directory. With no
  editor chosen, the app plain text opens in, as it does in a worktree being
  created or removed, which takes no new tab or shell. An application editor
  still takes the file there, unless it is reached through its command-line
  shim, which runs in a shell. Never the file's own type's handler, which can
  run it, Python Launcher for a `.py`; refused outright, every `.py`, `.js` or
  `.sh` a developer clicked beeped. Ghostty's app refuses them. Cost: a custom
  command is trusted as an editor, so `open {path}` hands a script on to
  whatever runs it.
- **The editor is handed the name the pane printed**, which keeps it inside a
  workspace opened through a symlink; a default app gets the resolved target,
  since Launch Services could judge a symlink by its own name. A path with `..`
  goes resolved to both: after a symlink it names another file than on disk.
- **The setting, not `$EDITOR`**: one choice of editor across the app, and
  `$EDITOR` is often a waiting line such as `code -w`, which would hold a tab
  open until the file closed.
- **Cost: another app's scheme, `vscode://` or `slack://`, opens nothing.**
  Ghostty's app asks before handing a scheme on.

## Reviewed and left as is

- **A `:line:column` strip can cut a path whose part after `/` starts with a
  combining mark** (2026-11-12). The whole text is tried first, so the strip
  only adds a fallback.
- **The pointer on a colon inside a run such as `": "` or `]:` finds no link**
  (2026-11-12). libghostty hands over the whole run, not the hovered cell, so a
  colon there is not told from the space or bracket beside it; no link on
  punctuation beats a link to the wrong file.

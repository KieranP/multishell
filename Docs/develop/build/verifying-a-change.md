# Verifying a change

## Before you say something works

- **Format what you touched, then lint, test, build and release.** All pass, no
  warnings.

## Driving a debug build

- **The command line drives a running copy without a click**, from opening tabs
  and typing in a pane to reading Debug Info and writing a screenshot;
  `multishell help` lists it. Each helper drives only its own build's app, so
  call `build/Multishell.app/Contents/Helpers/multishell`, not the `multishell`
  on PATH, which belongs to whichever build installed it (state-on-disk.md).
- **`multishell info` lists what is up**: an alert or dialog stalls a script
  that cannot click, and `multishell ui dismiss` cancels the topmost.
- **Look with `multishell debug screenshot`**, which writes a new PNG under
  `/tmp` and prints `{"path": …}`, then read it. It is the app drawing itself,
  terminals included, and needs no permission. `--settings` takes the settings
  window, which `ui show settings --page PAGE` turns to each page. Its sidebar's
  material and selected row draw flat or black there; the window does not.
- **Run it against a scratch home, never the account's.** A launch writes the
  state directory, re-points the helper links the installed app's hooks use, and
  its shells write history. `CFFIXED_USER_HOME` moves Foundation's home and
  `HOME` the helper's, so set both on the app and on every helper call.
- **A pane's shell still runs as the account**: the engine starts it through
  `/usr/bin/login -flp`, which sets `HOME` from the account, so it reads the
  real startup files and writes the real history. Typing into a pane in a
  scratch run wrote `~/.zsh_history`; drive the app without typing into panes.
- **Keep that home's path short**, a symlink from `/tmp` to the scratch
  directory: the socket sits under it, and `sun_path` holds 104 bytes.
- **Launch the binary itself**, `build/Multishell.app/Contents/MacOS/Multishell`
  under `env -i` with those two variables, not `open` or `multishell open`:
  LaunchServices passes no environment. Wait until `multishell info` answers,
  and end with `multishell quit --force`.
- **Turn `trashesRemovedWorktrees` off first** where a run removes worktrees, or
  they land in the account's Trash.

## What you cannot verify

- **You cannot drive the app's desktop.** No Apple events, no screen recording.
  Do not try, and do not ask for those permissions; the command line and its
  screenshots are the way in.
- **You can lay a view out in-process.** A hosting view inside a window that is
  never ordered in measures and renders, asking for nothing, and the sizing
  options give the size SwiftUI would refuse to go below.
  ViewSettingsWindowTests is the pattern.
- **It still needs a window server**, which is a session rather than a
  permission; CI's runner has one.
- **A tab band is drawn outside the AppKit hierarchy**: in no bitmap and in no
  measured size, so a band that clips stays invisible here.
- **The image renderer refuses a tab view outright** and draws a placeholder,
  where the AppKit display path renders the tab's content.
- **A minimum width reports where text stops wrapping**, not where a control is
  cut off, so it reads as a clip for any page with a caption.
- **`debug screenshot` shows terminals with their focus ring**, checked on a
  debug build (design/agents/command-line.md says how). An in-process render of
  a view has no live terminal to show.
- **Otherwise a view change stops at the checks above**: say what is unverified
  and leave the looking to the user. It takes no issue, since whether a feature
  draws and works is checked by hand as it is built.

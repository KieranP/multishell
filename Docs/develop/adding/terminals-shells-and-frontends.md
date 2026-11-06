# Terminals, shells and frontends

What a terminal engine, a shell, a command wrapper or a second frontend needs
beyond the code itself.

- **A terminal engine.** There is one, named outright where the Mac half builds
  the model (design/terminals/engine-and-config.md). A replacement implements
  the surface-host protocol and is passed to the model there.
- **What a host owes**: the session environment to the child, a finished command
  reported if the engine can tell, paste framed as a bracketed paste, typed text
  sent unbracketed as keystrokes so a shell runs the line, and each session's
  pty path and foreground pid where it knows them, without which Debug Info puts
  every pane under Other processes.
- **A host pastes copied files as the delegate's `textForPastedFiles` words
  them**, so an agent gets mentions, and a copied image as a file saved to the
  drops directory, only for the user's own paste
  (design/terminals/paste-and-drop.md).
- **A surface host also gives a pane's text, frame and last drawn image** where
  it can, which `panes read`, `tabs show` and `debug screenshot` answer from;
  one that cannot returns `nil` and the request is refused or the frame left
  out. Search counts reach the model through the delegate's `didCount`, and a
  host that sends none leaves `panes find` printing what it has at its
  two-second limit. A host that cannot say a session's terminal memory returns
  `nil`, and Debug Info leaves that screen and scrollback in the app's row.
- **A host judges a clicked link itself** before anything opens it, and hands a
  text file to the delegate's `didAskToEdit` for the user's editor. Nothing
  forces either. Left to libghostty, a link once ran whatever a program printed,
  and from `ad97d33` one from a pane's text opens nothing
  (design/terminals/links.md).
- **Two engines at once needs a multiplexer**, one host per kind and a map from
  session to kind, so a running terminal keeps the engine that opened it.
- **A shell with command-status hooks.** A folder in the libraries' resources,
  copied whole in the manifest, whose init file carries the helper's and the
  agents' placeholders and joins the rest through `# include` lines, a
  `leading-path` file of its own among them. Then a path in `Paths`, a generator
  in the integration scripts, a write in the integration refresh, and a case in
  `ShellLaunch.initFileArguments`, the one way in for both a fresh tab and the
  shell taking over when an agent quits. Add its generated file to
  `everyGeneratedFileParsesInItsShell` and
  `everyPlaceholderIsFilledInAndTheAgentsAreNamed`. A shell macOS does not ship
  gets its Homebrew paths in `InstalledShells`, as fish has, so a machine
  without it drops those tests' cases.
- **It reports a command started and finished through the helper**, naming the
  program where it is one of the agents, and does nothing when the session
  variable is unset.
- **The engine's own shell integration is off**
  (design/terminals/shell-integration.md), so prompt marks, the directory
  report, the cursor's shape and the `sudo` and `ssh` wrappers are the new
  shell's scripts to write, bar what it writes itself, as fish 4 does its marks
  and directory. Without them its panes go without click-to-move, a clicked
  relative path resolves from where the pane started, and the shape and the
  wrappers are gone.
- **The refresh's new parameter takes a default**, so the test callers that pass
  it every path, `GeneratedIntegration`, `ShellTab` and ShellIntegrationTests,
  still compile without the new one and write that shell's file into the debug
  build's own integration folder.
- **As a login shell it runs agents' lines only if it is in
  `ShellInvocation.interactiveLoginShells`**; left out, they run through
  `/bin/sh` and miss its PATH. One whose syntax is not sh's also needs a branch
  picking its `leading-path` file in
  `ShellIntegrationScripts.leadingPathStatement(forShellNamed:)`, as fish has,
  or the line opens with a statement it cannot parse.
- **A shell that reads quotes unlike sh needs a branch in `ShellLine`'s scan**,
  as fish has for `\'` inside single quotes, or a placeholder in a custom agent
  or editor line runs as its variable's name (ShellLineTests). Every word the
  app types still goes through `AnyShellQuoting`, so check the new shell reads
  its spelling alike.
- **Add it to the searched shells if Homebrew leaves it out of `/etc/shells`**,
  and give it a row in COMPAT.md's table: the picker offers it, so a reader has
  to be told what it does not get.
- **A command wrapper.** A function in each shell's `command-wrappers` file,
  zsh's, bash's and fish's, run only where the user's
  `shell-integration-features` name it and standing back where they have a
  function of that name. Nothing holds the three files to one list. The bash one
  must also run under macOS's bash 3.2, which
  ShellIntegrationScriptsTests+CommandWrappers runs beside Homebrew's.
- **A second frontend.** A target in this package depending on the five
  libraries, the package exporting no library product; fix the model to its view
  type once, and implement the platform, surface host and notifier ports. The
  directory watcher and the socket are AppCore's already.
- **A port may do less.** Trash may delete outright, handing over to a running
  copy may return and leave the alert standing, a platform with no display link
  may never call back and leave the frame rate blank, and a notifier that needs
  no permission answers unavailable to both questions, which keeps the settings
  page from promising a dialog. A platform with no windows or menu bar lists
  none, and refuses `window size`, `window full-screen`, choosing a menu item
  and `debug screenshot`.

import MultishellProcess

extension Helper {
  static let paneUsage = """
    usage: multishell panes split [--down] [--tab TAB_ID]
        Split the focused pane of the tab in view, or of TAB_ID once shown, to
        the right or with --down below, and print the new pane's id as JSON.
    usage: multishell panes select PANE_ID
        Show its tab and give it the keyboard.
    usage: multishell panes close PANE_ID [--force]
        The tab goes with its last pane. Refused while its agent is working,
        unless --force.
    usage: multishell panes type PANE_ID TEXT [--enter]
    usage: multishell panes type PANE_ID [--enter] -- TEXT
        Type TEXT into the pane as keystrokes, not a paste, then press Return
        with --enter, so a shell runs it. The keyboard stays where it was.
        TEXT that starts with a dash goes after --. A request holds \(UnixSocketServer.maximumLineLength / 1024) KB.
    usage: multishell panes paste PANE_ID TEXT
    usage: multishell panes paste PANE_ID -- TEXT
        Put TEXT in as a paste, as a drop or Cmd+V does: bracketed where the
        program asked, so a newline in it waits at a prompt.
    usage: multishell panes key PANE_ID KEY...
        Press each KEY in turn, as a person would: a letter, digit or key of
        US punctuation (- = [ ] ; ' , . / ` \\), a lone capital being it with
        Shift, or enter, escape, tab, backspace, delete, space, up, down,
        left, right, home, end, pageup, pagedown or f1 to f12, after any of
        ctrl-, alt-, shift- and cmd-. So `panes key PANE_ID ctrl-c` interrupts,
        `shift-1` types !, and `escape` stops an agent's turn.
    usage: multishell panes show PANE_ID
        Print the pane as JSON: its tab, worktree, title, agent, whether it
        is live and focused, its state, the workers its agent has out, and
        its find bar where one is up.
    usage: multishell panes read PANE_ID [--lines N] [--scrollback] [--plain]
        Print the text on its screen, or with --scrollback every line it
        keeps; --lines N prints the last N. A pane out of view reads too.
        --plain prints the text alone rather than as JSON.
    usage: multishell panes wait PANE_ID --state STATE [--timeout SECONDS]
    usage: multishell panes wait PANE_ID --text PATTERN [--scrollback]
                                [--timeout SECONDS]
        Return once its state is STATE (none, idle, running, attention, done
        or error), printing the pane, or once a line on its screen matches
        the regular expression PATTERN, printing the pane's id and the line.
        --scrollback first reads every line the pane keeps, then watches its
        screen. Exits 1 after SECONDS, 30 by default.
    usage: multishell panes find PANE_ID TEXT
    usage: multishell panes find PANE_ID --next | --previous | --close
        Open the pane's find bar on TEXT, step to the next or previous
        match, or close it, and print the bar once the terminal's count has
        settled: its text, the matches in all, and which is selected, from 0.
        TEXT that starts with a dash goes after --.

    """
}

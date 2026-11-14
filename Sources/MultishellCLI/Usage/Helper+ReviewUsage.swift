extension Helper {
  static let reviewUsage = """
    usage: multishell review list [--worktree WORKTREE_ID]
        Print the worktree's review comments as JSON, in the order Send
        writes them: each one's path, lines, state, the agent it went to
        and its text. The worktree in view where none is named.
    usage: multishell review add PATH LINES TEXT [--removed] [--worktree WORKTREE_ID]
        Comment on LINES of PATH, inside the worktree, as the composer in its
        file tab adds one, and print the list. LINES is one number or
        FIRST-LAST, numbered by the file on disk, or with --removed by the
        committed side for lines the file no longer has. The file must be
        shown in a tab (`tabs open-file`), or where none is, in the shown All
        changes tab (`tabs open-all-changes`), in the main window, not covered
        or minimized; its lines are read again first, as they now are. TEXT
        that starts with a dash goes after --.
    usage: multishell review send [--to PANE_ID] [--worktree WORKTREE_ID]
        Write the comments waiting to be sent to a file and paste a mention
        of it into the agent's prompt, as Review's Send does, then print the
        list. No newline is typed. PANE_ID is a pane with an agent in the
        worktree, working or not; where none is named, the one Review's
        picker shows.
    usage: multishell review clear [--sent] [--worktree WORKTREE_ID]
        Remove every comment, or with --sent only those already sent, as
        Review's Clear sent does, and print the list.

    """
}

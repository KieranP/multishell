extension Helper {
  static let tabUsage = """
    usage: multishell tabs list [WORKTREE_ID]
        Print every worktree's tabs and panes, or one's, as JSON, with each
        pane's state: what a script waits on for done.
    usage: multishell tabs open WORKTREE_ID [--agent ID] [--prompt TEXT]
                                [-- COMMAND [ARGUMENT...]]
        Open a tab: a shell, an agent, or COMMAND through the login shell, a
        shell taking over when it quits. In a worktree out of view it opens
        without switching to it. Prints the tab's and its pane's ids as JSON.
    usage: multishell tabs show TAB_ID
        Print the tab as JSON: its worktree, title, state, and its pane tree,
        each split with its axis and the share each side takes, each pane on
        screen with its frame in points from the window's top left.
    usage: multishell tabs select TAB_ID
        Show it, selecting its worktree first where that is out of view.
    usage: multishell tabs close TAB_ID [--force]
        Refused while an agent in it is working, unless --force.
    usage: multishell tabs move TAB_ID --before TAB_ID | --after TAB_ID
        Move it beside another tab of its worktree, as a drag does.
    usage: multishell tabs rename TAB_ID [--] [TITLE]
        Name it; no TITLE hands the title back to the shell. A TITLE that
        starts with a dash goes after --.

    """
}

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
    usage: multishell tabs move TAB_ID --worktree WORKTREE_ID
        Move a terminal tab to another worktree, its shells still running, as
        a drop on that worktree's row does, and show that worktree.
    usage: multishell tabs move TAB_ID --new-group
        Give it a group of its own, right of the one it was in, as Move to
        New Group does. Refused for a group's only tab.
    usage: multishell tabs rename TAB_ID [--] [TITLE]
        Name it; no TITLE hands the title back to the shell. A TITLE that
        starts with a dash goes after --.
    usage: multishell tabs resize TAB_ID SHARE... [--at INDEX,INDEX...]
        Set the shares of a terminal tab's split, as dragging its dividers
        does: one SHARE a side, relative, so 1 2 gives the second side two
        thirds. --at names a split inside another by each child's index from
        the root, as `tabs show` nests them; without it, the outermost.
        Prints the tab as `tabs show` does.
    usage: multishell tabs clear-status TAB_ID
        Clear the dots of a terminal tab's panes, as its Clear Status does.
    usage: multishell tabs open-file WORKTREE_ID PATH
        Open the worktree's file at PATH, relative to the worktree, as a tab,
        as a click on its Files panel row does, and print the tab's id as
        JSON. A file open already is brought to the front. In a worktree out
        of view it opens without switching to it.
    usage: multishell tabs step TAB_ID --next | --previous
        Move a file tab's view to the next or previous change, as the arrows
        on its bar do. The tab must be on screen; refused where its arrow is
        greyed out.
    usage: multishell tabs find TAB_ID TEXT
    usage: multishell tabs find TAB_ID --next | --previous | --close
        As `panes find`, over a file tab on screen, and print the tab as `tabs
        show` does, its find bar with the matches in all and which is
        selected, from 0.

    """
}

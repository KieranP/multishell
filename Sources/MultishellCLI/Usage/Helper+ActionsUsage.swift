extension Helper {
  static let actionsUsage = """
    usage: multishell actions list WORKTREE_ID
           multishell actions run WORKTREE_ID NAME [--restart] [--force]
        list prints the worktree's project actions as JSON, as its play button
        lists them: each one's name, state and keys, then those a
        .multishell.json not yet trusted would add.
        run runs one in its own tab in the worktree, in the background as
        `tabs open` does. One whose tab still runs something, its own run or
        what came after it, is refused; --restart ends that and runs it
        again, and --force does so over an agent working in its tab.
        Quote a NAME with a space in it: "Run Migrations".

    """
}

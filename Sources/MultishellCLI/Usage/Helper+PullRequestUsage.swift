extension Helper {
  static let pullRequestUsage = """
    usage: multishell pr send [--checks] [--threads] [--to PANE_ID] [--worktree WORKTREE_ID]
        Write the items the pull request page has checked, its failing
        checks with their logs' tails and its unresolved review threads, to
        a file and paste a mention of it into the agent's prompt, as the
        page's Send does, then print how many went to which pane. No newline
        is typed. --checks sends only the checks and --threads only the
        threads; neither sends both. Failing required checks and every
        thread start checked. Where the page is not showing the worktree, or
        the app is in the background, its checks and threads are read for
        the Send.
        PANE_ID is a pane with an agent in the worktree, working or not;
        where none is named, the one the page's picker shows. The worktree
        in view where none is named.

    """
}

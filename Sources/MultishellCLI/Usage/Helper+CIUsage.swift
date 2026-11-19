extension Helper {
  static let ciUsage = """
    usage: multishell ci send [--to PANE_ID] [--worktree WORKTREE_ID]
        Write the failures the CI page has checked in the newest run, each
        failed job with its part of the run's report, to a file and paste a
        mention of it into the agent's prompt, as the page's Send does, then
        print how many went to which pane. No newline is typed. Every
        failure starts checked. The page reads the run's jobs only while it
        shows, so show it first with `multishell ui show ci`. PANE_ID is a
        pane with an agent in the worktree, working or not; where none is
        named, the one the page's picker shows. The worktree in view where
        none is named.

    """
}

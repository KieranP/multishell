extension Helper {
  static let projectUsage = """
    usage: multishell projects list
        Print every project as JSON: its id, name and path.
    usage: multishell projects add [PATH]
        Add the repository holding PATH, the directory this runs in by
        default, as Add Project does, and print its id.
    usage: multishell projects remove PROJECT_ID [--force]
        Remove it from the sidebar, closing its tabs; nothing on disk goes.
        Refused while an agent in it is working, unless --force.
    usage: multishell projects expand|collapse PROJECT_ID
        Open or close its row, as its chevron does.
    usage: multishell projects move PROJECT_ID --before PROJECT_ID | --after PROJECT_ID
        Move it above or below another project, as a drag does.
    usage: multishell projects refresh PROJECT_ID
        Ask git for its worktrees again, as its Refresh does, and return once
        it has answered.
    usage: multishell projects fetch PROJECT_ID
        Fetch from its remotes, as its Fetch does, and return once the
        worktrees and merge badges are read again. One under way already
        answers at once.

    """
}

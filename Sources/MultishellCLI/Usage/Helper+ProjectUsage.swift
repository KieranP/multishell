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

    """
}

extension Helper {
  static let filesUsage = """
    usage: multishell files list
        Print the Files panel's list as JSON, as it draws it now: the
        worktree, files or git, the filter, whether git's list is still
        being read, and each row with its depth, change and line counts.
        Refused while the panel is shut or shows a pull request or CI page;
        `ui menu "View > Files Panel"` opens it.
    usage: multishell files filter [TEXT]
        Filter the list as typing in its field does; no TEXT clears it.
        Prints the list.
    usage: multishell files expand|collapse PATH
        Open or close the folder at PATH in the list, as its chevron does,
        and print the list. PATH is the row's, as `files list` prints it.

    """
}
